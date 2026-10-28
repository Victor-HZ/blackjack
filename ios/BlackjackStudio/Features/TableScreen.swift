import BlackjackCore
import SwiftUI

/// An automatically dealt practice table. It never accepts cards from a live game.
struct TableScreen: View {
    @EnvironmentObject private var model: StudioModel
    @EnvironmentObject private var purchases: PurchaseStore
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showingRules = false
    @State private var showingHelp = false
    @State private var confirmingReset = false
    @State private var countAnswer = ""
    @State private var checkedRound: Int?
    @State private var countWasCorrect = false
    @FocusState private var countIsFocused: Bool

    private var game: GameState { model.snapshot.game }
    private var moves: [PlayerMove] { GameEngine.availableMoves(in: game) }
    private var advice: StrategyAdvice? { BasicStrategy.recommend(in: game) }
    private var showCoach: Bool { model.snapshot.preferences.showCoach }
    private var showCount: Bool { purchases.hasPro && model.snapshot.preferences.showCount }
    private var canDeal: Bool {
        !game.isRoundActive && model.snapshot.selectedStake <= game.bankrollCents
            && game.bankrollCents >= 100 && purchases.hasLoadedEntitlements
    }
    private var insuranceCost: Int { ((game.currentHand?.betCents ?? 0) + 1) / 2 }
    private var canRecall: Bool {
        purchases.hasPro && !showCount && game.phase == .settled
            && game.shoe.count < game.rules.decks * 52
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                scoreStrip
                feltTable
                coachingCard
                if purchases.hasPro { countingCard }
                if canRecall { recallCard }
                Label("Simulated cards. Practice points only.", systemImage: "checkmark.shield")
                    .font(.caption).foregroundStyle(StudioTheme.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 6)
            }
            .padding(20)
            .frame(maxWidth: 850)
            .frame(maxWidth: .infinity)
        }
        .background(StudioTheme.background)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Table")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .safeAreaInset(edge: .bottom, spacing: 0) { actionDock }
        .sheet(isPresented: $showingRules) {
            TableRulesSheet(rules: game.rules, isRoundActive: game.isRoundActive) { rules in
                guard purchases.hasPro, !game.isRoundActive else { return }
                model.snapshot.applyRules(rules)
                model.lastDecision = nil
                resetRecall()
            }
        }
        .sheet(isPresented: $showingHelp) { TableHelpSheet() }
        .confirmationDialog("Reset this practice table?", isPresented: $confirmingReset, titleVisibility: .visible) {
            Button("Reset table", role: .destructive) {
                guard !game.isRoundActive else { return }
                model.snapshot.resetTable()
                model.lastDecision = nil
                resetRecall()
            }
        } message: {
            Text("Restores 1,000 points and clears table statistics. Your lessons and drills stay saved.")
        }
        .onAppear { ensureAffordableStake() }
        .onChange(of: game.rounds) { _, _ in resetRecall(); ensureAffordableStake() }
        .tint(StudioTheme.accent)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(text: "PUT IT INTO PRACTICE")
            Text("One hand.\nA better decision.")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .tracking(-1).foregroundStyle(StudioTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder private var scoreStrip: some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 14) { scoreValues }
                .padding(20).frame(maxWidth: .infinity, alignment: .leading)
                .background(StudioTheme.surface, in: RoundedRectangle(cornerRadius: 22))
        } else {
            HStack(alignment: .top, spacing: 14) { scoreValues }
                .padding(20).frame(maxWidth: .infinity)
                .background(StudioTheme.surface, in: RoundedRectangle(cornerRadius: 22))
        }
    }

    @ViewBuilder private var scoreValues: some View {
        tableStat("Practice points", value: points(game.bankrollCents))
        tableStat("Strategy", value: model.snapshot.accuracy.map { "\(Int(($0 * 100).rounded()))%" } ?? "—")
        tableStat("Hands", value: game.rounds.formatted())
    }

    private func tableStat(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.caption).foregroundStyle(StudioTheme.muted)
            Text(value).font(.system(.title2, design: .rounded, weight: .semibold))
                .monospacedDigit().foregroundStyle(StudioTheme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var feltTable: some View {
        VStack(spacing: 23) {
            HStack(alignment: .top) {
                Text(game.rules.summary).font(.caption2.weight(.medium))
                Spacer(minLength: 10)
                Label("\(game.decksRemaining.formatted(.number.precision(.fractionLength(1)))) decks", systemImage: "square.stack.3d.up")
                    .font(.caption2)
            }
            .foregroundStyle(StudioTheme.lime.opacity(0.85))
            .padding(.horizontal, 20)

            dealerHand

            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Rectangle().fill(StudioTheme.lime.opacity(0.25)).frame(width: 38, height: 1)
                    Image(systemName: "suit.spade.fill").font(.caption)
                    Rectangle().fill(StudioTheme.lime.opacity(0.25)).frame(width: 38, height: 1)
                }
                Text("BLACKJACK PAYS \(game.rules.blackjackPayout.rawValue)")
                    .font(.system(.caption2, design: .rounded).weight(.medium)).tracking(2)
            }
            .foregroundStyle(StudioTheme.lime.opacity(0.8))
            .accessibilityHidden(true)

            playerHands

            if game.phase == .settled {
                Label(settlementText, systemImage: (game.history.last?.profitCents ?? 0) > 0 ? "checkmark.circle" : "equal.circle")
                    .font(.subheadline.weight(.medium)).multilineTextAlignment(.center)
                    .foregroundStyle(StudioTheme.lime)
                    .padding(.horizontal, 18).padding(.vertical, 10)
                    .background(.white.opacity(0.08), in: Capsule())
                    .padding(.horizontal, 20)
                    .accessibilityIdentifier("table.result")
            }
        }
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 28).fill(StudioTheme.forest.gradient)
                Ellipse().stroke(StudioTheme.lime.opacity(0.1), lineWidth: 1)
                    .padding(.horizontal, 15).padding(.vertical, 44)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28))
    }

    private var dealerHand: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Text("DEALER").font(.caption2.weight(.semibold)).tracking(2)
                if !game.dealer.isEmpty {
                    Text("\(game.dealerValue.total)\(game.holeRevealed ? "" : " + ?")")
                        .font(.caption.weight(.medium)).monospacedDigit()
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(.white.opacity(0.1), in: Capsule())
                        .accessibilityLabel(game.holeRevealed ? "Dealer total \(game.dealerValue.total)" : "Dealer shows \(game.dealerValue.total); one card is face down")
                }
            }
            .foregroundStyle(StudioTheme.lime)
            ViewThatFits(in: .horizontal) {
                dealerCards
                ScrollView(.horizontal) { dealerCards.padding(.horizontal, 20) }.scrollIndicators(.hidden)
            }
        }
        .padding(.horizontal, 12)
        .accessibilityElement(children: .contain)
    }

    private var dealerCards: some View {
        HStack(spacing: game.dealer.count > 4 ? -18 : 6) {
            if game.dealer.isEmpty {
                NativePlayingCard(faceDown: true, width: 59)
                NativePlayingCard(faceDown: true, width: 59)
            } else {
                ForEach(Array(game.dealer.enumerated()), id: \.offset) { index, card in
                    NativePlayingCard(card: card, faceDown: index == 1 && !game.holeRevealed, width: 59)
                }
            }
        }
        .padding(.vertical, 5)
    }

    @ViewBuilder private var playerHands: some View {
        if game.hands.isEmpty {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    placeholderCard("suit.spade")
                    placeholderCard("suit.club")
                }
                Text("Your seat is ready.").font(.subheadline).foregroundStyle(StudioTheme.lime.opacity(0.85))
            }
            .padding(.vertical, 10)
        } else if game.hands.count == 1, let hand = game.hands.first {
            handView(hand, index: 0)
                .padding(.horizontal, 14)
        } else {
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 24) {
                        ForEach(Array(game.hands.enumerated()), id: \.offset) { index, hand in
                            handView(hand, index: index).id(index)
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .scrollIndicators(.hidden)
                .onChange(of: game.activeHand) { _, index in
                    if reduceMotion { proxy.scrollTo(index, anchor: .center) }
                    else { withAnimation(.easeInOut(duration: 0.2)) { proxy.scrollTo(index, anchor: .center) } }
                }
            }
        }
    }

    private func handView(_ hand: PlayerHand, index: Int) -> some View {
        let active = game.phase == .playing && index == game.activeHand
        let cardWidth: CGFloat = game.hands.count > 1 ? 62 : 76
        return VStack(spacing: 11) {
            ViewThatFits(in: .horizontal) {
                handCards(hand, width: cardWidth)
                ScrollView(.horizontal) { handCards(hand, width: cardWidth).padding(.horizontal, 10) }.scrollIndicators(.hidden)
            }
            HStack(spacing: 8) {
                Text(game.hands.count > 1 ? "HAND \(index + 1)" : "YOUR HAND")
                    .font(.caption2.weight(.medium)).tracking(1.5)
                Text("\(hand.value.total)\(hand.value.soft ? " soft" : "")")
                    .font(.caption.weight(.semibold)).monospacedDigit()
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(.white.opacity(hand.value.bust ? 0.2 : 0.1), in: Capsule())
                if let outcome = hand.outcome {
                    Text(outcome.title).font(.caption.weight(.medium))
                }
            }
            .foregroundStyle(StudioTheme.lime)
            Text("\(points(hand.betCents)) points")
                .font(.caption).foregroundStyle(StudioTheme.lime.opacity(0.8))
            if active {
                Capsule().fill(StudioTheme.lime).frame(width: 48, height: 3).accessibilityHidden(true)
            }
        }
        .padding(.bottom, 3)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(active ? "Your active hand \(index + 1)" : "Your hand \(index + 1)")
    }

    private func handCards(_ hand: PlayerHand, width: CGFloat) -> some View {
        HStack(spacing: hand.cards.count > 3 ? -width * 0.3 : 6) {
            ForEach(Array(hand.cards.enumerated()), id: \.offset) { _, card in
                NativePlayingCard(card: card, width: width)
            }
        }.padding(.vertical, 7)
    }

    private func placeholderCard(_ symbol: String) -> some View {
        RoundedRectangle(cornerRadius: 10)
            .stroke(StudioTheme.lime.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            .frame(width: 72, height: 101)
            .overlay { Image(systemName: symbol).font(.title).foregroundStyle(StudioTheme.lime.opacity(0.3)) }
            .accessibilityHidden(true)
    }

    private var coachingCard: some View {
        StudioCard {
            VStack(alignment: .leading, spacing: 15) {
                Toggle(isOn: Binding(get: { showCoach }, set: { model.snapshot.preferences.showCoach = $0 })) {
                    Label("Strategy coach", systemImage: "sparkle")
                        .font(.headline).foregroundStyle(StudioTheme.ink)
                }
                .accessibilityIdentifier("table.coach")
                if showCoach {
                    if let advice {
                        Text("\(advice.move.title) is the move.")
                            .font(.title3.weight(.semibold)).foregroundStyle(StudioTheme.ink)
                        Text(advice.reason).font(.subheadline).foregroundStyle(StudioTheme.muted)
                    } else if game.phase == .insurance {
                        Text("Skip insurance.").font(.title3.weight(.semibold)).foregroundStyle(StudioTheme.ink)
                        Text("Basic strategy declines this separate side bet.").font(.subheadline).foregroundStyle(StudioTheme.muted)
                    } else if let last = model.lastDecision {
                        Label(model.lastDecisionCorrect ? "Good decision." : "\(last.move.title) was stronger.", systemImage: model.lastDecisionCorrect ? "checkmark.circle" : "lightbulb")
                            .font(.headline).foregroundStyle(StudioTheme.ink)
                        Text(last.reason).font(.subheadline).foregroundStyle(StudioTheme.muted)
                    } else {
                        Text("Deal a hand. Find the right play.")
                            .font(.subheadline).foregroundStyle(StudioTheme.muted)
                    }
                } else {
                    Text("Trust your instinct. Review afterward.")
                        .font(.subheadline).foregroundStyle(StudioTheme.muted)
                }
            }
        }
    }

    private var countingCard: some View {
        StudioCard {
            VStack(alignment: .leading, spacing: 18) {
                Toggle(isOn: Binding(get: { showCount }, set: { model.snapshot.preferences.showCount = $0 })) {
                    Label("Show the count", systemImage: "square.stack.3d.up")
                        .font(.headline).foregroundStyle(StudioTheme.ink)
                }
                .accessibilityIdentifier("table.count")
                if showCount {
                    HStack(spacing: 28) {
                        countStat("Running", value: signed(game.runningCount))
                        countStat("True count", value: signedDecimal(game.trueCount))
                    }
                } else {
                    Text("Keep the running count in your head. Check it after the hand.")
                        .font(.subheadline).foregroundStyle(StudioTheme.muted)
                }
            }
        }
    }

    private func countStat(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption).foregroundStyle(StudioTheme.muted)
            Text(value).font(.system(.title, design: .rounded, weight: .semibold)).monospacedDigit().foregroundStyle(StudioTheme.accent)
        }.frame(maxWidth: .infinity, alignment: .leading).accessibilityElement(children: .combine)
    }

    private var recallCard: some View {
        StudioCard {
            VStack(alignment: .leading, spacing: 16) {
                Label("What’s the running count?", systemImage: "brain")
                    .font(.headline).foregroundStyle(StudioTheme.ink)
                if checkedRound == game.rounds {
                    Label(countWasCorrect ? "Correct. \(signed(game.runningCount))." : "The count is \(signed(game.runningCount)).", systemImage: countWasCorrect ? "checkmark.circle.fill" : "arrow.counterclockwise")
                        .font(.title3.weight(.medium)).foregroundStyle(StudioTheme.accent)
                        .accessibilityIdentifier("table.count-feedback")
                } else {
                    HStack(spacing: 12) {
                        Button { changeCount(by: -1) } label: {
                            Image(systemName: "minus").frame(width: 48, height: 48)
                        }
                        .background(StudioTheme.soft, in: RoundedRectangle(cornerRadius: 14))
                        .accessibilityLabel("Decrease your count answer")
                        TextField("0", text: $countAnswer)
                            .keyboardType(.numbersAndPunctuation).submitLabel(.done)
                            .multilineTextAlignment(.center).font(.title2.monospacedDigit())
                            .padding(.vertical, 12).background(StudioTheme.soft, in: RoundedRectangle(cornerRadius: 14))
                            .focused($countIsFocused).onSubmit { checkCount() }
                            .accessibilityLabel("Your running count").accessibilityIdentifier("table.count-answer")
                        Button { changeCount(by: 1) } label: {
                            Image(systemName: "plus").frame(width: 48, height: 48)
                        }
                        .background(StudioTheme.soft, in: RoundedRectangle(cornerRadius: 14))
                        .accessibilityLabel("Increase your count answer")
                    }
                    Button("Check count") { checkCount() }
                        .buttonStyle(StudioPrimaryButton())
                        .disabled(Int(countAnswer) == nil)
                        .opacity(Int(countAnswer) == nil ? 0.5 : 1)
                        .accessibilityIdentifier("table.check-count")
                }
            }
        }
    }

    @ViewBuilder private var actionDock: some View {
        VStack(spacing: 12) {
            if game.phase == .insurance {
                Text("Dealer shows an ace.").font(.headline).foregroundStyle(StudioTheme.ink)
                Text("Insurance costs \(points(insuranceCost)) points.")
                    .font(.caption).foregroundStyle(StudioTheme.muted)
                Button("No insurance") { model.play(.declineInsurance) }
                    .buttonStyle(StudioPrimaryButton()).accessibilityIdentifier("table.decline-insurance")
                Button("Take insurance") { model.play(.insurance) }
                    .font(.subheadline.weight(.medium)).frame(minHeight: 44)
                    .disabled(game.bankrollCents < insuranceCost)
                    .accessibilityIdentifier("table.insurance")
            } else if game.phase == .playing {
                if typeSize.isAccessibilitySize {
                    HStack(spacing: 10) { moveButton(.hit); moveButton(.stand) }
                    let secondaryMoves = moves.filter { $0 != .hit && $0 != .stand }
                    if !secondaryMoves.isEmpty {
                        Menu {
                            ForEach(secondaryMoves, id: \.self) { move in
                                Button(move.title, systemImage: move.symbol) { model.play(move.action) }
                            }
                        } label: {
                            Label("More moves", systemImage: "ellipsis.circle")
                                .font(.headline).frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .accessibilityIdentifier("table.more-moves")
                    }
                } else {
                    HStack(spacing: 10) { moveButton(.hit); moveButton(.stand) }
                    HStack(spacing: 9) { moveButton(.doubleDown); moveButton(.split); moveButton(.surrender) }
                }
            } else if game.bankrollCents < 100 {
                Text("Ready for a fresh start?").font(.headline).foregroundStyle(StudioTheme.ink)
                Button("Reset practice table") { confirmingReset = true }
                    .buttonStyle(StudioPrimaryButton()).accessibilityIdentifier("table.reset-empty")
            } else {
                stakeSelector
                Button {
                    countIsFocused = false
                    if !purchases.hasPro && game.rules != .standard { model.snapshot.applyRules(.standard) }
                    model.play(.deal(betCents: model.snapshot.selectedStake))
                    resetRecall()
                } label: {
                    HStack { Text(game.rounds == 0 ? "Deal a hand" : "Next hand"); Image(systemName: "arrow.right") }
                }
                .buttonStyle(StudioPrimaryButton()).disabled(!canDeal).opacity(canDeal ? 1 : 0.5)
                .accessibilityIdentifier("table.deal")
            }
        }
        .padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 12)
        .frame(maxWidth: 850)
        .frame(maxWidth: .infinity)
        .background(StudioTheme.background)
        .overlay(alignment: .top) { Divider().overlay(StudioTheme.line) }
    }

    private var stakeSelector: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                Text("Stake").font(.caption).foregroundStyle(StudioTheme.muted)
                stakeChips
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Practice stake").font(.caption).foregroundStyle(StudioTheme.muted)
                ScrollView(.horizontal) { HStack(spacing: 12) { stakeChips } }.scrollIndicators(.hidden)
            }
        }
    }

    @ViewBuilder private var stakeChips: some View {
        ForEach([500, 2_500, 5_000, 10_000], id: \.self) { cents in
            Button {
                model.snapshot.selectedStake = cents
            } label: {
                Text(points(cents)).font(.subheadline.weight(.semibold)).monospacedDigit()
                    .frame(minWidth: 48, minHeight: 44)
                    .foregroundStyle(model.snapshot.selectedStake == cents ? StudioTheme.forest : StudioTheme.ink)
                    .background(model.snapshot.selectedStake == cents ? StudioTheme.lime : StudioTheme.soft, in: Capsule())
                    .overlay(Capsule().stroke(StudioTheme.line, lineWidth: 1))
            }
            .disabled(cents > game.bankrollCents)
            .opacity(cents > game.bankrollCents ? 0.4 : 1)
            .accessibilityLabel("Stake \(points(cents)) points")
            .accessibilityAddTraits(model.snapshot.selectedStake == cents ? .isSelected : [])
        }
        if game.bankrollCents < 500 {
            Button("\(points(game.bankrollCents))") { model.snapshot.selectedStake = game.bankrollCents }
                .font(.subheadline.weight(.semibold)).frame(minWidth: 48, minHeight: 44)
                .background(StudioTheme.soft, in: Capsule())
                .accessibilityLabel("Stake remaining \(points(game.bankrollCents)) points")
        }
    }

    private func moveButton(_ move: PlayerMove) -> some View {
        let available = moves.contains(move)
        let recommended = showCoach && advice?.move == move
        return Button { model.play(move.action) } label: {
            VStack(spacing: 6) {
                Image(systemName: move.symbol).font(.headline)
                Text(move.title).font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 55)
            .padding(.vertical, 5)
            .foregroundStyle(recommended ? StudioTheme.forest : StudioTheme.ink)
            .background(recommended ? StudioTheme.lime : StudioTheme.soft, in: RoundedRectangle(cornerRadius: 15))
        }
        .disabled(!available).opacity(available ? 1 : 0.35)
        .accessibilityLabel(move.title)
        .accessibilityHint(recommended ? "Recommended by basic strategy" : "")
        .accessibilityIdentifier("table.\(move == .doubleDown ? "double" : move.rawValue)")
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("Table rules", systemImage: "slider.horizontal.3") {
                    if purchases.hasPro { showingRules = true } else { model.showPaywall = true }
                }.accessibilityIdentifier("table.rules")
                Button("New shoe", systemImage: "arrow.triangle.2.circlepath") {
                    model.play(.shuffle); resetRecall()
                }.disabled(game.isRoundActive)
                Button("How to play", systemImage: "questionmark.circle") { showingHelp = true }
                Button("Reset table", systemImage: "arrow.counterclockwise", role: .destructive) { confirmingReset = true }
                    .disabled(game.isRoundActive)
            } label: {
                Image(systemName: "slider.horizontal.3").frame(width: 44, height: 44)
            }
            .accessibilityLabel("Table options").accessibilityIdentifier("table.options")
        }
    }

    private var settlementText: String {
        guard let round = game.history.last else { return "Hand complete" }
        if round.profitCents == 0 && game.insuranceBetCents == 0 && round.outcomes.allSatisfy({ $0 == .push }) { return "Push. Stake returned." }
        if round.profitCents == 0 { return "Round even." }
        let sign = round.profitCents > 0 ? "+" : "−"
        return "\(sign)\(points(abs(round.profitCents))) practice points"
    }

    private func points(_ cents: Int) -> String {
        (Double(cents) / 100).formatted(.number.precision(.fractionLength(0...2)))
    }
    private func signed(_ number: Int) -> String { number > 0 ? "+\(number)" : number.formatted() }
    private func signedDecimal(_ number: Double) -> String {
        "\(number > 0 ? "+" : "")\(number.formatted(.number.precision(.fractionLength(1))))"
    }
    private func changeCount(by amount: Int) {
        let current = min(999, max(-999, Int(countAnswer) ?? 0))
        countAnswer = String(min(999, max(-999, current + amount)))
    }
    private func checkCount() {
        guard canRecall, checkedRound != game.rounds, let answer = Int(countAnswer) else { return }
        countIsFocused = false
        countWasCorrect = answer == game.runningCount
        checkedRound = game.rounds
        if countWasCorrect { StudioHaptics.success(enabled: model.snapshot.preferences.haptics) }
    }
    private func ensureAffordableStake() {
        guard !game.isRoundActive, game.bankrollCents >= 100,
              model.snapshot.selectedStake > game.bankrollCents else { return }
        model.snapshot.selectedStake = min(500, game.bankrollCents)
    }
    private func resetRecall() { countAnswer = ""; checkedRound = nil; countIsFocused = false }
}

private struct TableRulesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Rules
    let isRoundActive: Bool
    let onApply: (Rules) -> Void

    init(rules: Rules, isRoundActive: Bool, onApply: @escaping (Rules) -> Void) {
        _draft = State(initialValue: rules)
        self.isRoundActive = isRoundActive
        self.onApply = onApply
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Decks", selection: $draft.decks) {
                        ForEach([4, 6, 8], id: \.self) { Text("\($0) decks").tag($0) }
                    }
                    Picker("Blackjack payout", selection: $draft.blackjackPayout) {
                        Text("3 to 2").tag(BlackjackPayout.threeToTwo)
                        Text("6 to 5").tag(BlackjackPayout.sixToFive)
                    }
                    Toggle("Dealer hits soft 17", isOn: $draft.hitSoft17)
                    Toggle("Double after split", isOn: $draft.doubleAfterSplit)
                    Toggle("Late surrender", isOn: $draft.surrender)
                } footer: {
                    Text("A new shoe starts when you apply rules. Practice points and completed hands are preserved.")
                }
                if isRoundActive {
                    Section { Label("Finish this hand before applying rules.", systemImage: "hand.raised") }
                }
                Section {
                    Button("Use standard rules") { draft = .standard }
                }
            }
            .navigationTitle("Table rules").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") { onApply(draft); dismiss() }.fontWeight(.semibold).disabled(isRoundActive)
                }
            }
            .tint(StudioTheme.accent)
        }
    }
}

private struct TableHelpSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    help("The goal", "Get closer to 21 than the dealer without going over. Aces count as 1 or 11; picture cards count as 10.")
                    help("Your moves", "Hit takes a card. Stand keeps your total. Double adds the same stake for one final card. Split makes two hands from a pair.")
                    help("Table details", "Surrender returns half the stake. Insurance is a separate bet on dealer blackjack. Split aces receive one card; split 21 pays as a regular win.")
                    Label("Private practice with simulated cards only.", systemImage: "checkmark.shield")
                        .font(.subheadline).foregroundStyle(StudioTheme.accent)
                }.padding(24).frame(maxWidth: 600).frame(maxWidth: .infinity)
            }
            .background(StudioTheme.background)
            .navigationTitle("How to play").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }.tint(StudioTheme.accent)
    }
    private func help(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline).foregroundStyle(StudioTheme.ink)
            Text(text).font(.body).foregroundStyle(StudioTheme.muted)
        }
    }
}
