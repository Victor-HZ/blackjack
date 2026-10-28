import StoreKit
import SwiftUI
import UIKit

/// A transparent, non-subscription upgrade. Prices always come from the App Store.
struct PaywallView: View {
    @EnvironmentObject private var purchases: PurchaseStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var legalDocument: CommerceLegalDocument?
    @State private var completedUnlock = false

    var onUnlocked: (() -> Void)? = nil

    private var isBusy: Bool { purchases.isPurchasing || purchases.isRestoring }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if !typeSize.isAccessibilitySize {
                        upgradeArtwork
                            .frame(maxWidth: .infinity)
                            .padding(.top, 10)
                            .accessibilityHidden(true)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Label("STUDIO PRO", systemImage: "sparkle")
                            .font(.caption.weight(.bold))
                            .tracking(2)
                            .foregroundStyle(CommercePalette.forest)
                        Text("Make it\nsecond nature.")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                            .tracking(-1.3)
                            .fixedSize(horizontal: false, vertical: true)
                            .foregroundStyle(CommercePalette.ink)
                        Text("Your complete counting toolkit.\nOne payment. No subscription.")
                            .font(.body)
                            .foregroundStyle(CommercePalette.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    VStack(alignment: .leading, spacing: 22) {
                        benefit("Every training mode", detail: "Pairs, full decks, and true counts.", symbol: "rectangle.on.rectangle.angled")
                        benefit("The complete learning path", detail: "Build each skill in the right order.", symbol: "book.closed")
                        benefit("A table that grows with you", detail: "Adjust the rules. Put your skills to work.", symbol: "suit.spade")
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(CommercePalette.surface, in: RoundedRectangle(cornerRadius: 24))

                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.shield")
                            .foregroundStyle(CommercePalette.forest)
                        Text("Free training stays free. Your progress comes with you.")
                            .font(.subheadline)
                            .foregroundStyle(CommercePalette.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 4)
                    if let message = purchases.errorMessage ?? purchases.statusMessage {
                        statusCard(message, isError: purchases.errorMessage != nil)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .background(CommercePalette.background)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                purchaseFooter
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(CommercePalette.ink)
                            .frame(width: 44, height: 44)
                            .background(CommercePalette.surface.opacity(0.8), in: Circle())
                    }
                    .disabled(isBusy)
                    .accessibilityLabel("Close upgrade")
                    .accessibilityIdentifier("paywall.close")
                }
            }
            .toolbarBackground(CommercePalette.background, for: .navigationBar)
            .sheet(item: $legalDocument) { document in
                CommerceLegalView(document: document)
            }
            .interactiveDismissDisabled(isBusy)
            .task {
                await purchases.start()
                if purchases.hasPro { finishUnlock() }
            }
            .onChange(of: purchases.hasPro) { _, hasPro in
                if hasPro { finishUnlock() }
            }
        }
        .tint(CommercePalette.forest)
    }

    private var purchaseFooter: some View {
        VStack(spacing: 12) {
            Button {
                Task { await purchases.purchase() }
            } label: {
                HStack(spacing: 10) {
                    if purchases.isPurchasing {
                        ProgressView().tint(CommercePalette.cream)
                        Text("Confirming purchase…")
                    } else if let product = purchases.product {
                        Text("Unlock Pro · \(product.displayPrice)")
                        Image(systemName: "arrow.right")
                    } else if purchases.isLoading {
                        ProgressView().tint(CommercePalette.cream)
                        Text("Loading App Store…")
                    } else {
                        Text("Upgrade unavailable")
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 56)
                .foregroundStyle(CommercePalette.cream)
                .background(CommercePalette.forest, in: RoundedRectangle(cornerRadius: 17))
                .opacity(purchases.canPurchase || purchases.isPurchasing ? 1 : 0.55)
            }
            .disabled(!purchases.canPurchase)
            .accessibilityHint("A one-time purchase. There is no subscription.")
            .accessibilityIdentifier("paywall.purchase")

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 20) { footerLinks }
                VStack(spacing: 0) { footerLinks }
            }
            Text("Purchase charged to your Apple Account.")
                .font(.caption2)
                .foregroundStyle(CommercePalette.secondary)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .background(CommercePalette.background)
        .overlay(alignment: .top) { Divider().overlay(CommercePalette.forest.opacity(0.08)) }
    }

    @ViewBuilder
    private var footerLinks: some View {
        Button {
            Task { await purchases.restore() }
        } label: {
            HStack(spacing: 5) {
                if purchases.isRestoring { ProgressView().controlSize(.mini) }
                Text(purchases.isRestoring ? "Restoring…" : "Restore Purchases")
            }
            .font(.caption.weight(.medium))
            .frame(minHeight: 44)
        }
        .disabled(isBusy)
        .accessibilityIdentifier("paywall.restore")
        legalLink("Privacy", document: .privacy, url: CommerceConfiguration.privacyURL)
        legalLink("Terms", document: .terms, url: CommerceConfiguration.termsURL)
    }

    @ViewBuilder
    private func legalLink(_ title: String, document: CommerceLegalDocument, url: URL?) -> some View {
        if let url {
            Link(title, destination: url)
                .font(.caption)
                .frame(minHeight: 44)
        } else {
            Button(title) { legalDocument = document }
                .font(.caption)
                .frame(minHeight: 44)
        }
    }

    private func benefit(_ title: String, detail: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(CommercePalette.forest)
                .frame(width: 27, height: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline).foregroundStyle(CommercePalette.ink)
                Text(detail).font(.subheadline).foregroundStyle(CommercePalette.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private func statusCard(_ message: String, isError: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text(message)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: isError ? "wifi.exclamationmark" : "info.circle")
            }
            if purchases.product == nil && !purchases.isLoading {
                Button("Try again") {
                    Task { await purchases.refresh() }
                }
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: 44)
                .disabled(isBusy)
            }
        }
        .foregroundStyle(CommercePalette.secondary)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CommercePalette.surface, in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .contain)
    }

    private var upgradeArtwork: some View {
        ZStack {
            Circle()
                .fill(CommercePalette.lime.opacity(0.65))
                .frame(width: 164, height: 164)
            roundedCard(symbol: "suit.club.fill", foreground: CommercePalette.lime, background: CommercePalette.artForest)
                .rotationEffect(.degrees(-14))
                .offset(x: -32, y: 4)
            roundedCard(symbol: "suit.spade.fill", foreground: CommercePalette.artForest, background: .white)
                .rotationEffect(.degrees(12))
                .offset(x: 30, y: -2)
            Image(systemName: "sparkle")
                .font(.title2)
                .foregroundStyle(CommercePalette.forest)
                .offset(x: 94, y: -53)
        }
        .frame(height: 180)
    }

    private func roundedCard(symbol: String, foreground: Color, background: Color) -> some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(background)
            .frame(width: 92, height: 128)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: 37, weight: .regular))
                    .foregroundStyle(foreground)
            }
            .shadow(color: CommercePalette.forest.opacity(0.12), radius: 12, y: 8)
    }

    private func finishUnlock() {
        guard !completedUnlock else { return }
        completedUnlock = true
        onUnlocked?()
        dismiss()
    }
}

private enum CommercePalette {
    static let forest = adaptive(light: (22, 62, 50), dark: (203, 225, 158))
    static let background = adaptive(light: (247, 248, 242), dark: (16, 31, 24))
    static let surface = adaptive(light: (255, 255, 255), dark: (26, 45, 35))
    static let lime = Color(red: 223 / 255, green: 236 / 255, blue: 184 / 255)
    static let cream = adaptive(light: (248, 250, 240), dark: (22, 40, 30))
    static let ink = adaptive(light: (24, 45, 37), dark: (238, 243, 230))
    static let secondary = adaptive(light: (92, 111, 99), dark: (186, 200, 184))
    static let artForest = Color(red: 22 / 255, green: 62 / 255, blue: 50 / 255)

    private static func adaptive(light: (Double, Double, Double), dark: (Double, Double, Double)) -> Color {
        Color(uiColor: UIColor { traits in
            let rgb = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: rgb.0 / 255, green: rgb.1 / 255, blue: rgb.2 / 255, alpha: 1)
        })
    }
}
