import SwiftUI
import UIKit
import BlackjackCore

/// App surfaces follow iOS appearance, elevation, and accessibility contrast.
/// Felt and card stock are materials; their colors remain legible in either mode.
enum StudioTheme {
    static let radius: CGFloat = 16
    static func adaptive(_ light: UInt32, _ dark: UInt32, highContrastLight: UInt32? = nil, highContrastDark: UInt32? = nil) -> Color {
        Color(uiColor: UIColor { traits in
            let darkMode = traits.userInterfaceStyle == .dark
            let value: UInt32
            if traits.accessibilityContrast == .high {
                value = darkMode ? (highContrastDark ?? dark) : (highContrastLight ?? light)
            } else { value = darkMode ? dark : light }
            return UIColor(red: CGFloat((value >> 16) & 255) / 255, green: CGFloat((value >> 8) & 255) / 255, blue: CGFloat(value & 255) / 255, alpha: 1)
        })
    }
    static let background = Color(uiColor: .systemGroupedBackground)
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    static let soft = Color(uiColor: .tertiarySystemGroupedBackground)
    static let ink = Color(uiColor: .label)
    static let muted = adaptive(0x636366, 0xAEAEB2, highContrastLight: 0x3A3A3C, highContrastDark: 0xD1D1D6)
    static let line = adaptive(0xD8D8DC, 0x38383A, highContrastLight: 0x8E8E93, highContrastDark: 0x8E8E93)
    static let accent = adaptive(0x326348, 0xA7C9B0, highContrastLight: 0x214E35, highContrastDark: 0xC6E9CE)
    static let buttonFill = adaptive(0x202321, 0xF2F2F7)
    static let buttonText = adaptive(0xFFFFFF, 0x1C1C1E)
    static let red = adaptive(0xA84038, 0xFFAAA3)
    static let amber = adaptive(0x765C1B, 0xDEC183)

    static let felt = adaptive(0x164331, 0x10291E)
    static let onFelt = Color(red: 0.95, green: 0.96, blue: 0.91)
    static let cardPaper = Color(red: 0.98, green: 0.98, blue: 0.95)
    static let cardInk = Color(red: 0.10, green: 0.22, blue: 0.17)
    static let cardRed = Color(red: 0.66, green: 0.25, blue: 0.22)
    // Kept as material aliases for table art and existing card illustrations.
    static let forest = felt
    static let lime = onFelt
}

struct StudioPrimaryButton: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var light = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline).padding(.horizontal, 16).padding(.vertical, 14)
            .frame(maxWidth: .infinity).frame(minHeight: 52)
            .foregroundStyle(light ? StudioTheme.cardInk : StudioTheme.buttonText)
            .background(light ? StudioTheme.cardPaper : StudioTheme.buttonFill, in: RoundedRectangle(cornerRadius: 12))
            .opacity(isEnabled ? (configuration.isPressed ? 0.78 : 1) : 0.38)
            .contentShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct StudioCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(StudioTheme.surface, in: RoundedRectangle(cornerRadius: StudioTheme.radius))
    }
}

struct Eyebrow: View {
    var text: String
    var body: some View {
        Text(text).font(.caption.weight(.medium)).foregroundStyle(StudioTheme.muted)
    }
}

struct SectionTitle: View {
    var title: String
    var caption: String? = nil
    @Environment(\.dynamicTypeSize) private var textSize
    var body: some View {
        let layout = textSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 5)) : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
        layout {
            Text(title).font(.headline).foregroundStyle(StudioTheme.ink).accessibilityAddTraits(.isHeader)
            if !textSize.isAccessibilitySize { Spacer() }
            if let caption { Text(caption).font(.caption).foregroundStyle(StudioTheme.muted) }
        }.accessibilityElement(children: .combine)
    }
}

struct ProBadge: View {
    var body: some View {
        Text("Pro").font(.caption.weight(.medium)).foregroundStyle(StudioTheme.muted)
            .accessibilityLabel("Pro feature")
    }
}

struct NativePlayingCard: View {
    var card: BlackjackCore.Card?
    var faceDown = false
    var width: CGFloat = 76
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: width * 0.09).fill(StudioTheme.cardPaper)
            if faceDown || card == nil {
                RoundedRectangle(cornerRadius: width * 0.06).fill(StudioTheme.cardInk).padding(4)
                RoundedRectangle(cornerRadius: width * 0.04).stroke(StudioTheme.cardPaper.opacity(0.3), lineWidth: 1).padding(8)
                Image(systemName: "suit.spade.fill").font(.system(size: width * 0.28)).foregroundStyle(StudioTheme.cardPaper.opacity(0.85))
            } else if let card {
                let color = card.suit.isRed ? StudioTheme.cardRed : StudioTheme.cardInk
                Text(card.suit.symbol).font(.system(size: width * 0.45, design: .serif)).foregroundStyle(color)
                VStack {
                    HStack { corner(card, color); Spacer() }
                    Spacer()
                    HStack { Spacer(); corner(card, color).rotationEffect(.degrees(180)) }
                }.padding(width * 0.09)
            }
        }.frame(width: width, height: width * 1.42)
            .shadow(color: .black.opacity(0.14), radius: 2, x: 0, y: 1)
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
    var lineWidth: CGFloat = 4
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
        VStack(spacing: 10) {
            Image(systemName: symbol).font(.title2).foregroundStyle(StudioTheme.muted).padding(.bottom, 4)
            Text(title).font(.headline).foregroundStyle(StudioTheme.ink)
            Text(message).font(.subheadline).foregroundStyle(StudioTheme.muted).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.vertical, 25)
    }
}

enum StudioHaptics {
    @MainActor static func tap(enabled: Bool) { if enabled { UIImpactFeedbackGenerator(style: .light).impactOccurred() } }
    @MainActor static func success(enabled: Bool) { if enabled { UINotificationFeedbackGenerator().notificationOccurred(.success) } }
}
