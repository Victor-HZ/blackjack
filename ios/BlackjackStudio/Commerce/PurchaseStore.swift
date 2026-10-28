import Combine
import Foundation
import StoreKit

/// The only authority for Pro access is a verified StoreKit entitlement.
/// No preference, local database value, or UI-test argument grants paid access.
@MainActor
final class PurchaseStore: ObservableObject {
    @Published private(set) var hasPro = false
    @Published private(set) var product: Product?
    @Published private(set) var isLoading = false
    @Published private(set) var isPurchasing = false
    @Published private(set) var isRestoring = false
    @Published private(set) var hasLoadedEntitlements = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var statusMessage: String?

    let productID: String

    private var updatesTask: Task<Void, Never>?
    private var startupTask: Task<Void, Never>?
    private var hasStarted = false
    private var entitlementRevision: UInt = 0
    private var productLoadError: String?

    init(productID: String = CommerceConfiguration.proProductID) {
        self.productID = productID
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                await self.handleUpdate(result)
            }
        }
        startupTask = Task { [weak self] in
            guard let self else { return }
            await self.start()
        }
    }

    deinit {
        updatesTask?.cancel()
        startupTask?.cancel()
    }

    var canPurchase: Bool {
        product != nil && !hasPro && !isLoading && !isPurchasing && !isRestoring
    }

    /// Safe to call from the root view as well as after initialization.
    func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        await refresh()
    }

    /// StoreKit supplies signed, locally cached entitlements while offline.
    /// Product loading is independent: losing connectivity never revokes an owned unlock.
    func refresh() async {
        guard !isLoading && !isPurchasing && !isRestoring else { return }
        isLoading = true
        defer { isLoading = false }
        await refreshEntitlements()
        for await result in Transaction.unfinished {
            await handleUpdate(result)
        }
        await loadProduct()
    }

    func purchase() async {
        guard canPurchase, let product else { return }
        clearMessage()
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try verified(verification)
                guard transaction.productID == productID,
                      transaction.productType == .nonConsumable,
                      transaction.revocationDate == nil else {
                    errorMessage = "This purchase could not be verified. Please try restoring your purchases."
                    return
                }
                // Deliver from the verified transaction before acknowledging completion.
                applyVerifiedOwnership(true)
                statusMessage = nil
                await transaction.finish()
            case .pending:
                statusMessage = "Your purchase is awaiting approval. Pro will unlock when Apple confirms it."
            case .userCancelled:
                break
            @unknown default:
                statusMessage = "The purchase hasn’t completed. Please try again."
            }
        } catch {
            errorMessage = purchaseErrorMessage(error)
        }
    }

    /// User-initiated only: AppStore.sync() can prompt for App Store authentication.
    func restore() async {
        guard !isRestoring && !isPurchasing else { return }
        clearMessage()
        isRestoring = true
        defer { isRestoring = false }

        do {
            try await AppStore.sync()
            await refreshEntitlements()
            statusMessage = hasPro
                ? "Pro is restored. Your training is ready."
                : "No Pro purchase was found for this Apple Account."
        } catch {
            errorMessage = "Purchases couldn’t be restored. Check your connection and try again."
        }
    }

    func clearMessage() {
        errorMessage = nil
        statusMessage = nil
    }

    private func loadProduct() async {
        do {
            let products = try await Product.products(for: [productID])
            product = products.first { $0.id == productID && $0.type == .nonConsumable }
            if product == nil && !hasPro {
                reportProductLoadError("The upgrade isn’t available right now. Please try again later.")
            } else {
                if errorMessage == productLoadError { errorMessage = nil }
                productLoadError = nil
            }
        } catch {
            // A previously loaded Product remains valid for another purchase attempt.
            if product == nil && !hasPro {
                reportProductLoadError("Couldn’t connect to the App Store. Your free training is still available.")
            }
        }
    }

    private func reportProductLoadError(_ message: String) {
        // Background product refreshes must not replace a user-initiated purchase/restore error.
        if errorMessage == nil || errorMessage == productLoadError { errorMessage = message }
        productLoadError = message
    }

    private func refreshEntitlements() async {
        entitlementRevision &+= 1
        let revision = entitlementRevision
        var verifiedOwnership = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.productID == productID,
                  transaction.productType == .nonConsumable,
                  transaction.revocationDate == nil else { continue }
            verifiedOwnership = true
        }
        // Never overwrite a newer signed update with an older asynchronous enumeration.
        guard revision == entitlementRevision else { return }
        hasPro = verifiedOwnership
        hasLoadedEntitlements = true
    }

    private func handleUpdate(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else {
            // An unverified transaction must never grant access or be acknowledged as delivered.
            return
        }
        guard transaction.productID == productID, transaction.productType == .nonConsumable else { return }
        // A verified update is authoritative, including refunds and family-sharing revocation.
        applyVerifiedOwnership(transaction.revocationDate == nil)
        if hasPro { statusMessage = nil }
        await transaction.finish()
    }

    private func applyVerifiedOwnership(_ active: Bool) {
        entitlementRevision &+= 1
        hasPro = active
        hasLoadedEntitlements = true
    }

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value): return value
        case .unverified: throw PurchaseError.failedVerification
        }
    }

    private func purchaseErrorMessage(_ error: Error) -> String? {
        if error is PurchaseError {
            return "Apple couldn’t verify this purchase. You haven’t been given Pro access. Try Restore Purchases if you were charged."
        }
        if let error = error as? StoreKitError {
            switch error {
            case .userCancelled: return nil
            case .networkError: return "The App Store couldn’t be reached. Check your connection and try again."
            case .notAvailableInStorefront: return "This upgrade isn’t available in your App Store region."
            default: break
            }
        }
        return "The purchase didn’t complete. Please try again, or use Restore Purchases if you were charged."
    }

    private enum PurchaseError: Error { case failedVerification }
}

/// Release values are injected by the app's Info.plist / build configuration.
/// Never embed credentials or an App Store Connect API key in the application.
enum CommerceConfiguration {
    static var proProductID: String {
        let configured = Bundle.main.object(forInfoDictionaryKey: "ProProductID") as? String
        let trimmed = configured?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "com.example.blackjackstudio.pro" : trimmed
    }

    static var privacyURL: URL? { validHTTPSURL(for: "PrivacyPolicyURL") }
    static var termsURL: URL? { validHTTPSURL(for: "TermsOfUseURL") }

    private static func validHTTPSURL(for key: String) -> URL? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              let url = URL(string: value),
              url.scheme?.lowercased() == "https",
              let host = url.host, !host.isEmpty,
              host != "example.com", !host.hasSuffix(".example.com") else { return nil }
        return url
    }
}
