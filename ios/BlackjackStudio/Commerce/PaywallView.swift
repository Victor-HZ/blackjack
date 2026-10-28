import StoreKit
import SwiftUI

/// A one-time upgrade. StoreKit is the source of ownership and localized pricing.
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
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Blackjack Studio Pro")
                            .font(.title.bold())
                            .foregroundStyle(StudioTheme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        Text("One purchase. No subscription.")
                            .font(.body)
                            .foregroundStyle(StudioTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(spacing: 0) {
                        feature("Four additional drills", detail: "Pairs, shoe stamina, deck estimation, and true counts.", symbol: "rectangle.stack")
                        featureDivider
                        feature("The complete course", detail: "Eight lessons with short knowledge checks.", symbol: "book.closed")
                        featureDivider
                        feature("Custom table rules", detail: "Rule variations and count recall after each hand.", symbol: "slider.horizontal.3")
                    }
                    .background(StudioTheme.surface, in: RoundedRectangle(cornerRadius: StudioTheme.radius))
                    .overlay(RoundedRectangle(cornerRadius: StudioTheme.radius).strokeBorder(StudioTheme.line, lineWidth: 0.5))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Included without Pro")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(StudioTheme.ink)
                        Text("Card values, running counts, introductory lessons, and the standard practice table.")
                            .font(.subheadline)
                            .foregroundStyle(StudioTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 2)

                    if let message = purchases.errorMessage ?? purchases.statusMessage {
                        statusCard(message, isError: purchases.errorMessage != nil)
                    }
                }
                .padding(24)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .background(StudioTheme.background)
            .safeAreaInset(edge: .bottom, spacing: 0) { purchaseFooter }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.medium))
                            .foregroundStyle(StudioTheme.muted)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .disabled(isBusy)
                    .accessibilityLabel("Close upgrade")
                    .accessibilityIdentifier("paywall.close")
                }
            }
            .toolbarBackground(StudioTheme.background, for: .navigationBar)
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
        .tint(StudioTheme.accent)
    }

    private var featureDivider: some View {
        Rectangle().fill(StudioTheme.line).frame(height: 0.5).padding(.leading, 56)
    }

    private var purchaseFooter: some View {
        VStack(spacing: 8) {
            Button {
                Task { await purchases.purchase() }
            } label: {
                HStack(spacing: 10) {
                    if purchases.isPurchasing {
                        ProgressView().tint(StudioTheme.buttonText)
                        Text("Confirming purchase…")
                    } else if let product = purchases.product {
                        Text("Unlock Pro · \(product.displayPrice)")
                    } else if purchases.isLoading {
                        ProgressView().tint(StudioTheme.buttonText)
                        Text("Loading App Store…")
                    } else {
                        Text("Upgrade unavailable")
                    }
                }
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
                .padding(.vertical, 15)
                .frame(maxWidth: .infinity, minHeight: 52)
                .foregroundStyle(StudioTheme.buttonText)
                .background(StudioTheme.buttonFill, in: RoundedRectangle(cornerRadius: 14))
                .opacity(purchases.canPurchase || purchases.isPurchasing ? 1 : 0.45)
            }
            .disabled(!purchases.canPurchase)
            .accessibilityHint("A one-time purchase. There is no subscription.")
            .accessibilityIdentifier("paywall.purchase")

            if typeSize.isAccessibilitySize {
                VStack(spacing: 0) { footerLinks }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 20) { footerLinks }
                    VStack(spacing: 0) { footerLinks }
                }
            }
            Text("Charged to your Apple Account.")
                .font(.caption)
                .foregroundStyle(StudioTheme.muted)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity)
        .background(StudioTheme.background)
        .overlay(alignment: .top) { Rectangle().fill(StudioTheme.line).frame(height: 0.5) }
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
            .font(.footnote.weight(.medium))
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
                .font(.footnote)
                .frame(minHeight: 44)
        } else {
            Button(title) { legalDocument = document }
                .font(.footnote)
                .frame(minHeight: 44)
        }
    }

    private func feature(_ title: String, detail: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.body)
                .foregroundStyle(StudioTheme.muted)
                .frame(width: 22, height: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.body.weight(.semibold)).foregroundStyle(StudioTheme.ink)
                Text(detail).font(.subheadline).foregroundStyle(StudioTheme.muted)
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(20)
        .accessibilityElement(children: .combine)
    }

    private func statusCard(_ message: String, isError: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(StudioTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: isError ? "exclamationmark.circle" : "info.circle")
                    .foregroundStyle(isError ? StudioTheme.red : StudioTheme.muted)
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
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(StudioTheme.surface, in: RoundedRectangle(cornerRadius: StudioTheme.radius))
        .overlay(RoundedRectangle(cornerRadius: StudioTheme.radius).strokeBorder(StudioTheme.line, lineWidth: 0.5))
        .accessibilityElement(children: .contain)
    }

    private func finishUnlock() {
        guard !completedUnlock else { return }
        completedUnlock = true
        onUnlocked?()
        dismiss()
    }
}
