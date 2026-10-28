import SwiftUI
import UIKit

enum CommerceLegalDocument: String, Identifiable {
    case privacy
    case terms
    var id: String { rawValue }
    var title: String { self == .privacy ? "Your privacy" : "Training terms" }
}

/// Readable in-app information, available offline. The publisher must also host
/// their own privacy/support pages and review the release terms before submission.
struct CommerceLegalView: View {
    let document: CommerceLegalDocument
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    if document == .privacy {
                        section("Your practice is yours.", "Training records and preferences are stored locally in the app. They are not sent to developer servers. Your device backups may include this data.")
                        section("No tracking.", "Blackjack Studio does not include advertising, analytics, tracking, or an account system.")
                        section("Apple handles purchases.", "Payments and purchase verification use Apple’s App Store. The app receives a verified purchase entitlement, not your payment details.")
                        section("You stay in control.", "Delete your practice records in Settings. This does not cancel or remove an App Store purchase.")
                    } else {
                        section("Practice, not a gambling service.", "Blackjack Studio teaches mental arithmetic and card-counting concepts with simulated cards. It does not accept wagers, award money, or guarantee gambling results.")
                        section("Keep the device away from live games.", "Use this app for private practice. Laws and venue rules vary. Do not use it at casino tables or to assist a live gambling game.")
                        section("Know the limits.", "Mental counting, device-assisted play, and casino access are different questions. A training lesson is not legal advice or permission to play in a particular venue.")
                        section("One-time Pro upgrade.", "A verified Pro purchase unlocks the paid training features. There is no recurring subscription. Restore Purchases uses the Apple Account that made the purchase. Refunds and billing are handled by Apple.")
                        section("Apple’s license terms.", "Your use of the app is also subject to Apple’s standard licensed application terms unless the publisher supplies applicable custom terms.")
                        Link("Apple’s standard license agreement", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                            .font(.subheadline.weight(.medium))
                            .frame(minHeight: 44, alignment: .leading)
                    }
                }
                .padding(24)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(document.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("legal.done")
                }
            }
        }
        .tint(Color.accentColor)
    }

    private func section(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            Text(body)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
