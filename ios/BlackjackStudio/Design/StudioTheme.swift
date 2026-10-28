import SwiftUI
import UIKit
import BlackjackCore

enum StudioTheme {
    static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let value = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((value >> 16) & 255) / 255, green: CGFloat((value >> 8) & 255) / 255, blue: CGFloat(value & 255) / 255, alpha: 1)
        })
    }
    static let background = adaptive(0xF6F7F1, 0x0F1D17)
    static let surface = adaptive(0xFFFFFF, 0x192B22)
    static let ink = adaptive(0x1C3328, 0xF0F4E8)
    static let muted = adaptive(0x667561, 0xA8B8A6)
    static let line = adaptive(0xE3E9DB, 0x2C4132)
    static let soft = adaptive(0xEDF2E3, 0x233B2A)
    static let forest = Color(red: 0.08, green: 0.24, blue: 0.18)
    static let lime = Color(red: 0.87, green: 0.93, blue: 0.70)
    static let accent = adaptive(0x2C6045, 0xCEE4A7)
    static let red = adaptive(0xA44439, 0xF2A697)
    static let amber = adaptive(0x806322, 0xE6C984)
}

struct StudioPrimaryButton: ButtonStyle {
    var light = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded)).frame(maxWidth: .infinity).padding(.vertical, 17)
            .foregroundStyle(light ? StudioTheme.forest : .white)
            .background(light ? StudioTheme.lime : StudioTheme.forest, in: RoundedRectangle(cornerRadius: 18))
            .opacity(configuration.isPressed ? 0.78 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 18))
    }
}

struct StudioCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(StudioTheme.surface, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(StudioTheme.line, lineWidth: 1))
    }
}

struct Eyebrow: View {
    var text: String
    var body: some View {
        Text(text.uppercased()).font(.system(.caption2, design: .rounded).weight(.bold))
            .tracking(2).foregroundStyle(StudioTheme.muted).accessibilityAddTraits(.isHeader)
    }
}

struct SectionTitle: View {
    var title: String
    var caption: String? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.system(.title3, design: .rounded).weight(.bold)).foregroundStyle(StudioTheme.ink)
            Spacer()
            if let caption { Text(caption).font(.caption).foregroundStyle(StudioTheme.muted) }
        }.accessibilityElement(children: .combine)
    }
}

struct ProBadge: View {
    var body: some View {
        Text("PRO").font(.system(.caption2, design: .rounded).weight(.heavy)).tracking(1)
            .padding(.horizontal, 8).padding(.vertical, 5).foregroundStyle(StudioTheme.accent)
            .background(StudioTheme.soft, in: Capsule()).accessibilityLabel("Pro feature")
    }
}

struct NativePlayingCard: View {
    var card: BlackjackCore.Card?
    var faceDown = false
    var width: CGFloat = 76
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: width * 0.11).fill(Color(red: 0.98, green: 0.98, blue: 0.94))
            if faceDown || card == nil {
                RoundedRectangle(cornerRadius: width * 0.075).fill(StudioTheme.forest).padding(5)
                RoundedRectangle(cornerRadius: width * 0.05).stroke(StudioTheme.lime.opacity(0.35), lineWidth: 1).padding(9)
                Image(systemName: "suit.spade.fill").font(.system(size: width * 0.32)).foregroundStyle(StudioTheme.lime)
            } else if let card {
                let color: Color = card.suit.isRed ? Color(red: 0.69, green: 0.26, blue: 0.24) : StudioTheme.forest
                Text(card.suit.symbol).font(.system(size: width * 0.45, design: .serif)).foregroundStyle(color)
                VStack {
                    HStack { corner(card, color); Spacer() }
                    Spacer()
                    HStack { Spacer(); corner(card, color).rotationEffect(.degrees(180)) }
                }.padding(width * 0.09)
            }
        }.frame(width: width, height: width * 1.42)
            .shadow(color: .black.opacity(0.12), radius: 7, x: 0, y: 4)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(faceDown || card == nil ? "Face-down card" : card!.accessibilityLabel)
    }
    private func corner(_ card: BlackjackCore.Card, _ color: Color) -> some View {
        VStack(spacing: -1) {
            Text(card.rank.rawValue).font(.system(size: width * 0.22, weight: .bold, design: .serif))
            Text(card.suit.symbol).font(.system(size: width * 0.16))
        }.foregroundStyle(color)
    }
}

struct ProgressRing: View {
    var progress: Double
    var lineWidth: CGFloat = 6
    var body: some View {
        ZStack {
            Circle().stroke(StudioTheme.line, lineWidth: lineWidth)
            Circle().trim(from: 0, to: min(1, max(0, progress))).stroke(StudioTheme.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)).rotationEffect(.degrees(-90))
        }.accessibilityHidden(true)
    }
}

struct EmptyState: View {
    var symbol: String
    var title: String
    var message: String
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: symbol).font(.system(size: 30, weight: .light)).foregroundStyle(StudioTheme.accent)
                .frame(width: 76, height: 76).background(StudioTheme.soft, in: RoundedRectangle(cornerRadius: 24))
            Text(title).font(.system(.title3, design: .rounded).weight(.bold)).foregroundStyle(StudioTheme.ink)
            Text(message).font(.subheadline).foregroundStyle(StudioTheme.muted).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.vertical, 32)
    }
}

enum StudioHaptics {
    @MainActor static func tap(enabled: Bool) { if enabled { UIImpactFeedbackGenerator(style: .light).impactOccurred() } }
    @MainActor static func success(enabled: Bool) { if enabled { UINotificationFeedbackGenerator().notificationOccurred(.success) } }
}
