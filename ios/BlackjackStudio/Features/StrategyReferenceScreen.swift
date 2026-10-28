import SwiftUI
import BlackjackCore

/// Total-dependent, two-card reference for the same rules used by the practice table.
struct StrategyReferenceScreen: View {
    @EnvironmentObject private var model: StudioModel
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var chartKind: StrategyChartKind = .hard
    @State private var firstRank: Rank = .ten
    @State private var secondRank: Rank = .six
    @State private var dealerRank: Rank = .ten
    @AccessibilityFocusState private var recommendationFocused: Bool

    private var rules: Rules { model.snapshot.game.rules }
    private var dealerRanks: [Rank] { [.two, .three, .four, .five, .six, .seven, .eight, .nine, .ten, .ace] }
    private var rows: [StrategyChartRow] { chartKind.rows }
    private var lookupAdvice: StrategyAdvice {
        BasicStrategy.recommend(cards: [Card(rank: firstRank, suit: .spades), Card(rank: secondRank, suit: .hearts)],
                                dealer: Card(rank: dealerRank, suit: .clubs), rules: rules)
    }
    private var cellWidth: CGFloat { typeSize.isAccessibilitySize ? 66 : 44 }
    private var cellHeight: CGFloat { typeSize.isAccessibilitySize ? 64 : 44 }
    private var labelWidth: CGFloat { typeSize.isAccessibilitySize ? 100 : 68 }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    lookupCard.id("strategy.lookup")
                    chartCard { row, dealer in
                        firstRank = row.cards[0].rank
                        secondRank = row.cards[1].rank
                        dealerRank = dealer
                        if reduceMotion { proxy.scrollTo("strategy.lookup", anchor: .top) }
                        else { withAnimation(.easeInOut(duration: 0.25)) { proxy.scrollTo("strategy.lookup", anchor: .top) } }
                        recommendationFocused = true
                    }
                    rulesCard
                }
                .padding(20)
                .frame(maxWidth: 900)
                .frame(maxWidth: .infinity)
            }
            .background(StudioTheme.background)
            .navigationTitle("Strategy guide")
            .navigationBarTitleDisplayMode(.inline)
            .tint(StudioTheme.accent)
        }
    }

    private var lookupCard: some View {
        StudioCard {
            VStack(alignment: .leading, spacing: 20) {
                SectionTitle(title: "Study a sample hand")
                if typeSize.isAccessibilitySize {
                    VStack(spacing: 14) { playerPickers }
                } else {
                    HStack(spacing: 14) { playerPickers }
                }
                rankPicker("Dealer’s upcard", selection: $dealerRank, ranks: dealerRanks, identifier: "strategy.dealerCard")
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: lookupAdvice.move.symbol)
                            .font(.title3.weight(.semibold))
                            .frame(width: 43, height: 43)
                            .foregroundStyle(StudioTheme.accent)
                        Text(lookupAdvice.move.title)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(StudioTheme.ink)
                    }
                    Text(lookupAdvice.reason)
                        .font(.subheadline)
                        .foregroundStyle(StudioTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(StudioTheme.soft, in: RoundedRectangle(cornerRadius: 12))
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("strategy.recommendation")
                .accessibilityFocused($recommendationFocused)
            }
        }
    }

    @ViewBuilder private var playerPickers: some View {
        rankPicker("Your first card", selection: $firstRank, ranks: Rank.allCases, identifier: "strategy.firstCard")
        rankPicker("Your second card", selection: $secondRank, ranks: Rank.allCases, identifier: "strategy.secondCard")
    }

    private func rankPicker(_ title: String, selection: Binding<Rank>, ranks: [Rank], identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.caption).foregroundStyle(StudioTheme.muted)
            Picker(title, selection: selection) {
                ForEach(ranks, id: \.self) { rank in
                    Text(rank.name).tag(rank)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
            .padding(.horizontal, 12)
            .background(StudioTheme.background, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(StudioTheme.line))
            .accessibilityLabel(title)
            .accessibilityIdentifier(identifier)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func chartCard(onSelect: @escaping (StrategyChartRow, Rank) -> Void) -> some View {
        StudioCard {
            VStack(alignment: .leading, spacing: 17) {
                SectionTitle(title: "Basic strategy")
                chartPicker
                Text(chartKind.explanation)
                    .font(.footnote).foregroundStyle(StudioTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Spacer().frame(width: labelWidth)
                    Text("Dealer’s upcard")
                        .font(.caption.weight(.medium)).foregroundStyle(StudioTheme.muted)
                        .frame(maxWidth: .infinity)
                }
                HStack(alignment: .top, spacing: 4) {
                    // The hand column stays visible while the dealer columns scroll on a phone.
                    VStack(spacing: 4) {
                        Text("Hand")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(StudioTheme.muted)
                            .frame(width: labelWidth, height: cellHeight)
                        ForEach(rows) { row in
                            Text(row.label)
                                .lineLimit(1).minimumScaleFactor(0.65)
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(StudioTheme.ink)
                                .frame(width: labelWidth, height: cellHeight)
                                .background(StudioTheme.background, in: RoundedRectangle(cornerRadius: 9))
                                .accessibilityHidden(true)
                        }
                    }
                    ScrollView(.horizontal) {
                        VStack(spacing: 4) {
                            HStack(spacing: 4) {
                                ForEach(dealerRanks, id: \.self) { rank in
                                    Text(rank.rawValue)
                                        .font(.subheadline.weight(.semibold))
                                        .monospacedDigit()
                                        .foregroundStyle(StudioTheme.muted)
                                        .frame(width: cellWidth, height: cellHeight)
                                        .accessibilityHidden(true)
                                }
                            }
                            ForEach(rows) { row in
                                HStack(spacing: 4) {
                                    ForEach(dealerRanks, id: \.self) { rank in
                                        chartCell(row, dealer: rank) { onSelect(row, rank) }
                                    }
                                }
                            }
                        }
                        .padding(.trailing, 2)
                        .padding(.bottom, 4)
                    }
                    .scrollIndicators(.visible)
                    .accessibilityLabel("\(chartKind.title) strategy chart")
                }
                Text("Tap a play for its explanation. Swipe the chart for all upcards.")
                    .font(.caption).foregroundStyle(StudioTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                legend
                Text("Initial two-card hands. Double and split assume enough points. If a charted double is unavailable, hit below 18; stand on soft 18 or higher.")
                    .font(.footnote).foregroundStyle(StudioTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder private var chartPicker: some View {
        if typeSize.isAccessibilitySize {
            Picker("Hand type", selection: $chartKind) {
                ForEach(StrategyChartKind.allCases) { kind in Text(kind.title).tag(kind) }
            }.pickerStyle(.menu).accessibilityIdentifier("strategy.handType")
        } else {
            Picker("Hand type", selection: $chartKind) {
                ForEach(StrategyChartKind.allCases) { kind in Text(kind.title).tag(kind) }
            }.pickerStyle(.segmented).accessibilityIdentifier("strategy.handType")
        }
    }

    private func chartCell(_ row: StrategyChartRow, dealer: Rank, onSelect: @escaping () -> Void) -> some View {
        let advice = BasicStrategy.recommend(cards: row.cards, dealer: Card(rank: dealer, suit: .clubs), rules: rules,
                                            options: StrategyOptions(canDouble: true, canSplit: chartKind == .pairs,
                                                                     canSurrender: rules.surrender))
        let selected = row.cards[0].rank == firstRank && row.cards[1].rank == secondRank && dealer == dealerRank
        return Button(action: onSelect) {
            Text(StrategyChartStyle.letter(advice.move))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(StrategyChartStyle.foreground(advice.move))
                .frame(width: cellWidth, height: cellHeight)
                .background(StrategyChartStyle.background(advice.move), in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(selected ? StudioTheme.ink : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(chartKind.accessibilityName) \(row.label) against \(dealer.name): \(advice.move.title)")
        .accessibilityHint("Shows the hand and explanation above")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var legend: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 210 : 130), spacing: 12)], alignment: .leading, spacing: 12) {
            ForEach(PlayerMove.allCases, id: \.self) { move in
                HStack(spacing: 8) {
                    Text(StrategyChartStyle.letter(move)).font(.caption.weight(.bold))
                        .foregroundStyle(StrategyChartStyle.foreground(move))
                        .frame(width: 31, height: 31)
                        .background(StrategyChartStyle.background(move), in: RoundedRectangle(cornerRadius: 8))
                    Text(move.title).font(.caption).foregroundStyle(StudioTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }.accessibilityElement(children: .combine)
            }
        }
        .padding(.vertical, 3)
    }

    private var rulesCard: some View {
        StudioCard {
            VStack(alignment: .leading, spacing: 16) {
                Label("Your table rules", systemImage: "slider.horizontal.3")
                    .font(.headline).foregroundStyle(StudioTheme.ink)
                ruleLine("Decks", value: "\(rules.decks)")
                ruleLine("Dealer soft 17", value: rules.hitSoft17 ? "Hits" : "Stands")
                ruleLine("Double after split", value: rules.doubleAfterSplit ? "Allowed" : "Not allowed")
                ruleLine("Late surrender", value: rules.surrender ? "Allowed" : "Not allowed")
                Text("Updates with your practice table. This guide covers 4–8 deck games with a dealer hole card, without count-based deviations.")
                    .font(.footnote).foregroundStyle(StudioTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func ruleLine(_ title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).foregroundStyle(StudioTheme.muted)
            Spacer(minLength: 14)
            Text(value).foregroundStyle(StudioTheme.ink)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
    }
}

private enum StrategyChartKind: String, CaseIterable, Identifiable {
    case hard, soft, pairs
    var id: String { rawValue }
    var title: String {
        switch self {
        case .hard: return "Hard totals"
        case .soft: return "Soft totals"
        case .pairs: return "Pairs"
        }
    }
    var accessibilityName: String {
        switch self {
        case .hard: return "Hard"
        case .soft: return "Soft hand"
        case .pairs: return "Pair"
        }
    }
    var explanation: String {
        switch self {
        case .hard: return "No ace counted as 11."
        case .soft: return "The ace is counted as 11."
        case .pairs: return "Two cards of the same value."
        }
    }
    var rows: [StrategyChartRow] {
        switch self {
        case .hard:
            return (5...20).map { total in
                let first = total >= 12 ? 10 : 2
                let second = total - first
                return StrategyChartRow(label: String(total), first: rank(first), second: rank(second))
            }
        case .soft:
            return (2...9).map { StrategyChartRow(label: "A, \($0)", first: .ace, second: rank($0)) }
        case .pairs:
            return ([Rank.two, .three, .four, .five, .six, .seven, .eight, .nine, .ten, .ace]).map {
                StrategyChartRow(label: "\($0.rawValue), \($0.rawValue)", first: $0, second: $0)
            }
        }
    }
    private func rank(_ value: Int) -> Rank { Rank(rawValue: String(value)) ?? .ten }
}

private struct StrategyChartRow: Identifiable {
    let label: String
    let cards: [Card]
    var id: String { label }
    init(label: String, first: Rank, second: Rank) {
        self.label = label
        cards = [Card(rank: first, suit: .spades), Card(rank: second, suit: .hearts)]
    }
}

private enum StrategyChartStyle {
    static func letter(_ move: PlayerMove) -> String {
        switch move {
        case .hit: return "H"
        case .stand: return "S"
        case .doubleDown: return "D"
        case .split: return "P"
        case .surrender: return "R"
        }
    }
    static func background(_ move: PlayerMove) -> Color {
        switch move {
        case .hit: return StudioTheme.soft
        case .stand: return StudioTheme.forest
        case .doubleDown: return StudioTheme.adaptive(0xE0EBE3, 0x293E30)
        case .split: return StudioTheme.adaptive(0xE3ECF7, 0x263D53)
        case .surrender: return StudioTheme.adaptive(0xF4E9D6, 0x473A25)
        }
    }
    static func foreground(_ move: PlayerMove) -> Color {
        switch move {
        case .hit: return StudioTheme.ink
        case .stand: return .white
        case .doubleDown: return StudioTheme.accent
        case .split: return StudioTheme.adaptive(0x31526E, 0xC4DEF4)
        case .surrender: return StudioTheme.adaptive(0x775522, 0xF0D7A9)
        }
    }
}
