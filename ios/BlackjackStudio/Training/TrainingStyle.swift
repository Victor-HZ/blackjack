import SwiftUI
import TrainingCore

enum TrainingStyle {
    static let background = StudioTheme.background
    static let surface = StudioTheme.surface
    static let ink = StudioTheme.ink
    static let secondary = StudioTheme.muted
    static let border = StudioTheme.line
    static let soft = StudioTheme.soft
    static let accent = StudioTheme.accent
    static let felt = StudioTheme.felt
    static let onFelt = StudioTheme.onFelt
    static let radius = StudioTheme.radius
}
typealias TrainingPrimaryButton = StudioPrimaryButton

struct TrainingCardFace: View {
    let card: TrainingCard
    var width: CGFloat = 90
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: width * 0.11).fill(StudioTheme.cardPaper)
            Text(card.suit).font(.system(size: width * 0.43, weight: .regular, design: .serif))
            VStack {
                HStack(alignment: .top) { corner; Spacer(minLength: 0) }
                Spacer(minLength: 0)
                HStack(alignment: .bottom) { Spacer(minLength: 0); corner.rotationEffect(.degrees(180)) }
            }.padding(width * 0.10)
        }
        .foregroundStyle(card.isRed ? StudioTheme.cardRed : StudioTheme.cardInk)
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
