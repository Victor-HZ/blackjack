import SwiftUI
import UIKit
import TrainingCore

enum TrainingStyle {
    static let background = adaptive(0xF6F7F2, dark: 0x0E1E18)
    static let surface = adaptive(0xFFFFFF, dark: 0x192D24)
    static let ink = adaptive(0x203B2E, dark: 0xEDF2E5)
    static let secondary = adaptive(0x687866, dark: 0xAFBEA9)
    static let border = adaptive(0xE3E8DB, dark: 0x314335)
    static let soft = adaptive(0xECF1E2, dark: 0x263D2D)
    static let forest = Color(red: 0.09, green: 0.27, blue: 0.20)
    static let lime = Color(red: 0.87, green: 0.93, blue: 0.72)
    static let coral = adaptive(0xAD5747, dark: 0xF0A592)
    static func adaptive(_ light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1)
        })
    }
}
struct TrainingPrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).frame(maxWidth: .infinity).frame(minHeight: 54)
            .foregroundStyle(TrainingStyle.forest).background(TrainingStyle.lime.opacity(configuration.isPressed ? 0.8 : 1), in: RoundedRectangle(cornerRadius: 18))
    }
}
struct TrainingCardFace: View {
    let card: TrainingCard
    var width: CGFloat = 90
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13).fill(Color(red: 0.99, green: 0.98, blue: 0.94))
            Text(card.suit).font(.system(size: width * 0.43, weight: .regular, design: .serif))
            VStack {
                HStack(alignment: .top) { corner; Spacer(minLength: 0) }
                Spacer(minLength: 0)
                HStack(alignment: .bottom) { Spacer(minLength: 0); corner.rotationEffect(.degrees(180)) }
            }.padding(width * 0.10)
        }
        .foregroundStyle(card.isRed ? Color(red: 0.68, green: 0.26, blue: 0.22) : Color(red: 0.12, green: 0.25, blue: 0.19))
        .frame(width: width, height: width * 1.42)
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
        .accessibilityElement(children: .ignore).accessibilityLabel(card.accessibilityName)
    }
    private var corner: some View {
        VStack(spacing: 0) {
            Text(card.rank).font(.system(size: width * 0.23, weight: .semibold, design: .serif))
            Text(card.suit).font(.system(size: width * 0.16, design: .serif))
        }
    }
}
struct TrainingPill: View {
    let text: String
    var symbol: String? = nil
    var body: some View {
        HStack(spacing: 5) {
            if let symbol { Image(systemName: symbol) }
            Text(text)
        }.font(.caption.weight(.semibold)).padding(.horizontal, 10).padding(.vertical, 6)
            .foregroundStyle(TrainingStyle.secondary).background(TrainingStyle.soft, in: Capsule())
    }
}
