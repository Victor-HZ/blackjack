import SwiftUI
import BlackjackCore
import StudioCore
import TrainingCore

/// A finite session of simulated hands. Only first attempts contribute to its score.
struct SimulationScreen: View {
    @EnvironmentObject private var model: StudioModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rounds = 10
    @State private var mode: SimulationMode = .guided
    @State private var countChecks = true
    @State private var countAnswer = ""
    @State private var confirmingEnd = false
    private var parsedCount: Int? {
        guard let value = Int(countAnswer), (-416...416).contains(value) else { return nil }
        return value
    }
    @FocusState private var countIsFocused: Bool
    @AccessibilityFocusState private var feedbackFocused: Bool

    var body: some View {
        NavigationStack {
            Group {
                if let session = model.snapshot.activeSimulation {
                    if let summary = completedSummary(session) {
                        SimulationResultsView(summary: summary, onRepeat: {
                            model.startSimulation(summary.configuration)
                        })
                    } else {
                        sessionContent(session)
                    }
                } else { setup }
            }
            .background(StudioTheme.background)
            .navigationTitle("Simulation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        if model.snapshot.activeSimulation?.stage == .complete { model.closeCompletedSimulation() }
                        else { dismiss() }
                    }
                    .frame(minHeight: 44)
                    .accessibilityLabel(model.snapshot.activeSimulation == nil ? "Close simulation" : "Save and close simulation")
                    .accessibilityIdentifier("simulation.close")
                }
                if let session = model.snapshot.activeSimulation, session.stage != .complete {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("End session", role: .destructive) { confirmingEnd = true }
                        } label: {
                            Image(systemName: "ellipsis").frame(width: 44, height: 44)
                        }.accessibilityLabel("Session options")
                    }
                }
            }
            .confirmationDialog("End this session?", isPresented: $confirmingEnd, titleVisibility: .visible) {
                Button("End session", role: .destructive) { model.discardSimulation() }
                Button("Keep practicing", role: .cancel) {}
            } message: { Text("This unfinished session won’t be added to your results. Close instead to save and resume it.") }
        }
        .tint(StudioTheme.accent)
    }

    private func completedSummary(_ session: SimulationSession) -> SimulationSummary? {
        guard session.stage == .complete else { return nil }
        return model.snapshot.simulationSessions.first(where: { $0.id == session.id }) ?? session.summary()
    }

    private var setup: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 9) {
                    Text("Choose your session").font(.title2.weight(.semibold)).foregroundStyle(StudioTheme.ink)
                    Text("Play a set number of rounds, then review your decisions and count.")
                        .font(.body).foregroundStyle(StudioTheme.muted)
                }
                StudioCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Rounds").font(.headline).foregroundStyle(StudioTheme.ink)
                        if typeSize.isAccessibilitySize {
                            roundsPicker.pickerStyle(.menu)
                        } else { roundsPicker.pickerStyle(.segmented) }
                        Text("Split hands count as one round.").font(.footnote).foregroundStyle(StudioTheme.muted)
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle(title: "Feedback")
                    VStack(spacing: 0) {
                        modeRow(.guided, title: "Guided", detail: "Review each decision after you play.")
                        Divider().padding(.leading, 18)
                        modeRow(.test, title: "Test", detail: "Keep feedback hidden until the end.")
                    }.background(StudioTheme.surface, in: RoundedRectangle(cornerRadius: StudioTheme.radius))
                }
                StudioCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Check my running count", isOn: $countChecks)
                            .font(.headline).foregroundStyle(StudioTheme.ink)
                            .accessibilityIdentifier("simulation.countChecks")
                        Text("Recall the Hi-Lo count after each round. Cards are hidden while you answer.")
                            .font(.subheadline).foregroundStyle(StudioTheme.muted)
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Standard table · \(Rules.standard.summary)").font(.subheadline).foregroundStyle(StudioTheme.ink)
                    Text("Fixed practice stakes. Your score measures decisions, not wins.")
                        .font(.footnote).foregroundStyle(StudioTheme.muted)
                }
                Button {
                    model.startSimulation(SimulationConfiguration(rounds: rounds, mode: mode, countChecks: countChecks))
                } label: { Text("Start \(rounds) rounds") }
                    .buttonStyle(StudioPrimaryButton()).accessibilityIdentifier("simulation.start")
                Text("Simulated cards. No real-money play.").font(.caption).foregroundStyle(StudioTheme.muted)
                    .frame(maxWidth: .infinity)
            }.padding(20).frame(maxWidth: 650).frame(maxWidth: .infinity)
        }
    }

    private var roundsPicker: some View {
        Picker("Rounds", selection: $rounds) {
            ForEach([10, 25, 50], id: \.self) { Text("\($0)").tag($0) }
        }.accessibilityIdentifier("simulation.rounds")
    }

    private func modeRow(_ value: SimulationMode, title: String, detail: String) -> some View {
        Button { mode = value } label: {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.body.weight(.semibold)).foregroundStyle(StudioTheme.ink)
                    Text(detail).font(.subheadline).foregroundStyle(StudioTheme.muted)
                }.fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Image(systemName: mode == value ? "checkmark.circle.fill" : "circle")
                    .font(.title3).foregroundStyle(mode == value ? StudioTheme.accent : StudioTheme.muted)
                    .accessibilityHidden(true)
            }.padding(18).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityAddTraits(mode == value ? .isSelected : [])
            .accessibilityIdentifier(value == .guided ? "simulation.mode.guided" : "simulation.mode.test")
    }

    private func sessionContent(_ session: SimulationSession) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    sessionHeading(session).id("simulation.top")
                    if session.stage == .ready {
                        ready(session)
                    } else if session.stage == .countCheck || session.stage == .countFeedback {
                        countCheck(session)
                    } else {
                        if session.roundStartedNewShoe || session.shoeChangedDuringRound {
                            Label(session.shoeChangedDuringRound ? "New shoe dealt. The count reset to zero during this round." : "New shoe. Count starts at zero.", systemImage: "arrow.triangle.2.circlepath")
                                .font(.subheadline).foregroundStyle(StudioTheme.accent)
                                .accessibilityIdentifier("simulation.newShoe")
                        }
                        table(session.game)
                        switch session.stage {
                        case .playing: playControls(session)
                        case .decisionFeedback: decisionFeedback(session)
                        case .roundReview: roundReview(session)
                        default: EmptyView()
                        }
                    }
                }.padding(20).frame(maxWidth: 760).frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: session.stage) { _, stage in
                countIsFocused = false
                if stage == .countCheck { countAnswer = "" }
                if reduceMotion { proxy.scrollTo("simulation.top", anchor: .top) }
                else { withAnimation(.easeInOut(duration: 0.2)) { proxy.scrollTo("simulation.top", anchor: .top) } }
                feedbackFocused = stage == .decisionFeedback || stage == .countFeedback
            }
        }
    }

    private func sessionHeading(_ session: SimulationSession) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6)) : AnyLayout(HStackLayout())
            layout {
                Text("Round \(session.completedRounds + 1) of \(session.configuration.rounds)")
                    .font(.headline).foregroundStyle(StudioTheme.ink).accessibilityIdentifier("simulation.roundProgress")
                if !typeSize.isAccessibilitySize { Spacer() }
                Text(session.configuration.mode == .guided ? "Guided" : "Test")
                    .font(.subheadline).foregroundStyle(StudioTheme.muted)
            }
            ProgressView(value: Double(session.completedRounds), total: Double(session.configuration.rounds))
                .tint(StudioTheme.accent).accessibilityLabel("Rounds completed")
                .accessibilityValue("\(session.completedRounds) of \(session.configuration.rounds)")
            Text("Shoe \(session.shoeNumber) · \(session.configuration.rules.summary)")
                .font(.caption).foregroundStyle(StudioTheme.muted)
        }
    }

    private func ready(_ session: SimulationSession) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            StudioCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text(session.completedRounds == 0 ? "Ready to deal" : "Next round")
                        .font(.title2.weight(.semibold)).foregroundStyle(StudioTheme.ink)
                    Text(session.completedRounds == 0 ? (session.configuration.countChecks ? "Start your count at zero. Count every exposed card, including the dealer’s." : "Choose the best play for each hand.") : (session.configuration.countChecks ? "Carry your count into the next hand. A new-shoe notice tells you when to reset." : "Keep choosing the best play for the cards dealt."))
                        .font(.body).foregroundStyle(StudioTheme.muted)
                }
            }
            Button { model.dealSimulationRound() } label: { Text("Deal round \(session.completedRounds + 1)") }
                .buttonStyle(StudioPrimaryButton()).accessibilityIdentifier("simulation.deal")
        }
    }

    private func table(_ game: GameState) -> some View {
        VStack(spacing: 22) {
            VStack(spacing: 12) {
                Text(game.holeRevealed ? "Dealer · \(game.dealerValue.total)" : "Dealer")
                    .font(.subheadline.weight(.semibold))
                ScrollView(.horizontal) {
                    HStack(spacing: 7) {
                        ForEach(Array(game.dealer.enumerated()), id: \.offset) { index, card in
                            NativePlayingCard(card: card, faceDown: index == 1 && !game.holeRevealed, width: 58)
                        }
                    }.padding(.horizontal, 18).padding(.vertical, 4)
                }.scrollIndicators(.hidden)
            }
            Divider().overlay(StudioTheme.onFelt.opacity(0.2)).padding(.horizontal, 18)
            VStack(spacing: 18) {
                ForEach(Array(game.hands.enumerated()), id: \.offset) { index, hand in
                    VStack(spacing: 10) {
                        let label = game.hands.count == 1 ? "Your hand" : "Hand \(index + 1)"
                        Text("\(label) · \(hand.value.total)\(hand.value.soft ? " soft" : "")")
                            .font(.subheadline.weight(.semibold))
                        ScrollView(.horizontal) {
                            HStack(spacing: 7) {
                                ForEach(Array(hand.cards.enumerated()), id: \.offset) { _, card in NativePlayingCard(card: card, width: 64) }
                            }.padding(.horizontal, 18).padding(.vertical, 4)
                        }.scrollIndicators(.hidden)
                        if game.phase == .playing && game.activeHand == index {
                            Text("Your turn").font(.caption.weight(.semibold))
                        } else if let outcome = hand.outcome {
                            Text(outcome.title).font(.subheadline.weight(.medium))
                        }
                    }.padding(.vertical, 8)
                        .background(StudioTheme.onFelt.opacity(game.phase == .playing && game.activeHand == index && game.hands.count > 1 ? 0.08 : 0))
                }
            }
        }.foregroundStyle(StudioTheme.onFelt).padding(.vertical, 20)
            .frame(maxWidth: .infinity).background(StudioTheme.felt, in: RoundedRectangle(cornerRadius: StudioTheme.radius))
            .accessibilityIdentifier("simulation.table")
    }

    @ViewBuilder private func playControls(_ session: SimulationSession) -> some View {
        if session.game.phase == .insurance {
            VStack(alignment: .leading, spacing: 14) {
                Text("Take insurance?").font(.headline).foregroundStyle(StudioTheme.ink)
                Text("A separate side bet when the dealer shows an ace.").font(.subheadline).foregroundStyle(StudioTheme.muted)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: typeSize.isAccessibilitySize ? 1 : 2), spacing: 10) {
                    insuranceButton("No insurance", action: .declineInsurance, identifier: "simulation.declineInsurance")
                    insuranceButton("Take insurance", action: .insurance, identifier: "simulation.insurance")
                }
            }
        } else {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: typeSize.isAccessibilitySize ? 1 : 2), spacing: 10) {
                ForEach(GameEngine.availableMoves(in: session.game), id: \.self) { move in
                    Button { model.playSimulation(move.action) } label: {
                        Text(move.title).font(.headline).fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, minHeight: 52).padding(.horizontal, 8).padding(.vertical, 8)
                            .foregroundStyle(StudioTheme.ink)
                            .background(StudioTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(StudioTheme.line))
                    }.buttonStyle(.plain).accessibilityIdentifier("simulation.move.\(move.rawValue)")
                }
            }
        }
    }

    private func insuranceButton(_ title: String, action: GameAction, identifier: String) -> some View {
        Button { model.playSimulation(action) } label: {
            Text(title).font(.headline).fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 52).padding(.horizontal, 8).padding(.vertical, 8)
                .foregroundStyle(StudioTheme.ink)
                .background(StudioTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(StudioTheme.line))
        }.buttonStyle(.plain).accessibilityIdentifier(identifier)
    }

    @ViewBuilder private func decisionFeedback(_ session: SimulationSession) -> some View {
        if let decision = session.decisions.last {
            StudioCard {
                VStack(alignment: .leading, spacing: 12) {
                    Label(decision.correct ? "Correct decision" : "Review this decision", systemImage: decision.correct ? "checkmark.circle" : "info.circle")
                        .font(.headline).foregroundStyle(decision.correct ? StudioTheme.accent : StudioTheme.ink)
                    Text("\(decision.cards.map { $0.rank.rawValue }.joined(separator: ", ")) against \(decision.dealer.rank.rawValue)")
                        .font(.caption).foregroundStyle(StudioTheme.muted)
                    Text("You chose \(decision.chosen.title.lowercased()). \(decision.correct ? "" : "Recommended: \(decision.recommended.title).")")
                        .font(.subheadline).foregroundStyle(StudioTheme.ink)
                    Text(decision.explanation).font(.body).foregroundStyle(StudioTheme.muted)
                }.accessibilityElement(children: .combine).accessibilityFocused($feedbackFocused)
            }
            .accessibilityIdentifier("simulation.decisionFeedback")
            Button("Continue") { model.continueSimulationDecision() }
                .buttonStyle(StudioPrimaryButton()).accessibilityIdentifier("simulation.continueDecision")
        }
    }

    private func roundReview(_ session: SimulationSession) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Round complete").font(.headline).foregroundStyle(StudioTheme.ink).accessibilityIdentifier("simulation.roundComplete")
            if session.configuration.countChecks {
                Text("Count every exposed card before hiding the table.").font(.subheadline).foregroundStyle(StudioTheme.muted)
                Button("Check my count") { model.beginSimulationCount() }
                    .buttonStyle(StudioPrimaryButton()).accessibilityIdentifier("simulation.beginCount")
            } else { finishRoundButton(session) }
        }
    }

    @ViewBuilder private func countCheck(_ session: SimulationSession) -> some View {
        if session.stage == .countCheck {
            StudioCard {
                VStack(alignment: .leading, spacing: 18) {
                    Text("What’s the running count?").font(.title2.weight(.semibold)).foregroundStyle(StudioTheme.ink)
                    Text("Use the count from the whole shoe, not just this hand.").font(.subheadline).foregroundStyle(StudioTheme.muted)
                    TextField("0", text: $countAnswer)
                        .keyboardType(.numbersAndPunctuation).submitLabel(.done)
                        .font(.largeTitle.weight(.medium).monospacedDigit()).multilineTextAlignment(.center)
                        .padding(14).background(StudioTheme.background, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(StudioTheme.ink).focused($countIsFocused)
                        .onSubmit { submitCount() }
                        .accessibilityLabel("Your running count").accessibilityIdentifier("simulation.countAnswer")
                    Button("Submit count") { submitCount() }
                        .buttonStyle(StudioPrimaryButton()).disabled(parsedCount == nil)
                        .accessibilityIdentifier("simulation.submitCount")
                    if !countAnswer.isEmpty && parsedCount == nil {
                        Text("Enter a whole number from −416 to +416.").font(.footnote).foregroundStyle(StudioTheme.muted)
                    }
                }
            }
        } else if let response = session.countResponses.last {
            StudioCard {
                VStack(alignment: .leading, spacing: 12) {
                    if session.configuration.mode == .guided {
                        Label(response.correct ? "Correct count" : "Count correction", systemImage: response.correct ? "checkmark.circle" : "info.circle")
                            .font(.headline).foregroundStyle(response.correct ? StudioTheme.accent : StudioTheme.ink)
                        Text("Running count: \(signed(response.expectedCount))")
                            .font(.title2.weight(.semibold).monospacedDigit()).foregroundStyle(StudioTheme.ink)
                        if !response.correct {
                            Text("Your answer: \(signed(response.answer)). Continue from \(signed(response.expectedCount)).")
                                .font(.subheadline).foregroundStyle(StudioTheme.muted)
                        }
                    } else {
                        Text("Count saved").font(.headline).foregroundStyle(StudioTheme.ink)
                        Text("Review your answer when the session ends.").font(.subheadline).foregroundStyle(StudioTheme.muted)
                    }
                }.accessibilityElement(children: .combine).accessibilityFocused($feedbackFocused)
            }
            .accessibilityIdentifier("simulation.countFeedback")
            finishRoundButton(session)
        }
    }

    private func finishRoundButton(_ session: SimulationSession) -> some View {
        Button(session.completedRounds + 1 == session.configuration.rounds ? "See results" : "Next round") { model.finishSimulationRound() }
            .buttonStyle(StudioPrimaryButton()).accessibilityIdentifier("simulation.finishRound")
    }
    private func submitCount() {
        guard let value = parsedCount else { return }
        countIsFocused = false
        model.submitSimulationCount(value)
    }
    private func signed(_ value: Int) -> String { value > 0 ? "+\(value)" : "\(value)" }
}

/// Used by both the completed session and its saved entry in Progress.
struct SimulationResultsView: View {
    let summary: SimulationSummary
    var onRepeat: (() -> Void)? = nil
    var onPracticeCount: (() -> Void)? = nil
    @EnvironmentObject private var model: StudioModel
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Session complete").font(.title2.weight(.semibold)).foregroundStyle(StudioTheme.ink)
                    Text("\(summary.completedRounds) rounds · \(summary.configuration.mode == .guided ? "Guided" : "Test")")
                        .font(.subheadline).foregroundStyle(StudioTheme.muted)
                }
                VStack(spacing: 0) {
                    metric("Decisions", value: percent(summary.strategyAccuracy), detail: "\(summary.decisions.filter(\.correct).count) of \(summary.decisions.count) correct")
                    if summary.configuration.countChecks {
                        Divider().padding(.horizontal, 18)
                        metric("Running count", value: percent(summary.countAccuracy), detail: "\(summary.countResponses.filter(\.correct).count) of \(summary.countResponses.count) correct")
                    }
                }.background(StudioTheme.surface, in: RoundedRectangle(cornerRadius: StudioTheme.radius))
                Text("First attempts only. Winning a hand does not mean the decision was correct.")
                    .font(.footnote).foregroundStyle(StudioTheme.muted)
                if !summary.mistakes.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle(title: "Next practice")
                        if let topic = summary.weakestTopic {
                            Text("Focus on \(topic.title.lowercased()).").font(.body).foregroundStyle(StudioTheme.ink)
                        }
                        NavigationLink { SimulationMistakeReview(decisions: summary.mistakes) } label: {
                            Label("Practice \(summary.mistakes.count) missed \(summary.mistakes.count == 1 ? "decision" : "decisions")", systemImage: "arrow.counterclockwise")
                        }.buttonStyle(StudioPrimaryButton()).accessibilityIdentifier("simulation.review")
                        NavigationLink { StrategyReferenceScreen(referenceRules: summary.configuration.rules) } label: {
                            HStack { Text("Open strategy guide"); Spacer(); Image(systemName: "chevron.right").font(.caption) }
                                .font(.body).frame(minHeight: 44)
                        }
                    }
                } else if !summary.decisions.isEmpty {
                    Label("All decisions matched basic strategy", systemImage: "checkmark.circle")
                        .font(.body).foregroundStyle(StudioTheme.accent)
                } else {
                    Text("No strategy decisions were required in these hands. Try another session for a skill score.")
                        .font(.body).foregroundStyle(StudioTheme.muted)
                }
                if !summary.countMistakes.isEmpty {
                    countReview
                    Button { if let onPracticeCount { onPracticeCount() } else { model.practiceSimulationCount() } } label: { Text("Practice running count") }
                        .buttonStyle(StudioPrimaryButton()).accessibilityIdentifier("simulation.practiceCount")
                }
                if let onRepeat {
                    Button(action: onRepeat) { Text("Play another \(summary.configuration.rounds) rounds") }
                        .font(.headline).frame(maxWidth: .infinity, minHeight: 52)
                        .accessibilityIdentifier("simulation.repeat")
                }
            }.padding(20).frame(maxWidth: 700).frame(maxWidth: .infinity)
        }.background(StudioTheme.background).accessibilityIdentifier("simulation.results")
    }

    private func metric(_ title: String, value: String, detail: String) -> some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10)) : AnyLayout(HStackLayout(spacing: 16))
        return layout {
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline).foregroundStyle(StudioTheme.ink)
                Text(detail).font(.subheadline).foregroundStyle(StudioTheme.muted)
            }
            if !typeSize.isAccessibilitySize { Spacer() }
            Text(value).font(.title.weight(.semibold).monospacedDigit()).foregroundStyle(StudioTheme.ink)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(18).accessibilityElement(children: .combine)
    }

    private var countReview: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Count corrections")
            Text("2–6: +1 · 7–9: 0 · 10–A: −1. Reset only when a new shoe begins.")
                .font(.footnote).foregroundStyle(StudioTheme.muted)
            VStack(spacing: 0) {
                ForEach(summary.countMistakes) { response in
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Round \(response.round)").font(.subheadline.weight(.semibold)).foregroundStyle(StudioTheme.ink)
                        Text("Your count: \(signed(response.answer)) · Correct: \(signed(response.expectedCount))")
                            .font(.subheadline.monospacedDigit()).foregroundStyle(StudioTheme.muted)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(18).accessibilityElement(children: .combine)
                    if response.id != summary.countMistakes.last?.id { Divider().padding(.leading, 18) }
                }
            }.background(StudioTheme.surface, in: RoundedRectangle(cornerRadius: StudioTheme.radius))
        }
    }
    private func percent(_ value: Double?) -> String { value.map { "\(Int(($0 * 100).rounded()))%" } ?? "—" }
    private func signed(_ value: Int) -> String { value > 0 ? "+\(value)" : "\(value)" }
}

/// Retrieval practice reuses the exact hand and legal choices without changing the saved score.
private struct SimulationMistakeReview: View {
    let decisions: [SimulationDecision]
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    @State private var choice: SimulationChoice?
    @AccessibilityFocusState private var feedbackFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if decisions.indices.contains(index) {
                    let decision = decisions[index]
                    Text("\(index + 1) of \(decisions.count)").font(.subheadline).foregroundStyle(StudioTheme.muted)
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Dealer’s upcard").font(.subheadline.weight(.semibold))
                        NativePlayingCard(card: decision.dealer, width: 58)
                        Text("Your hand").font(.subheadline.weight(.semibold))
                        ScrollView(.horizontal) {
                            HStack(spacing: 8) {
                                ForEach(Array(decision.cards.enumerated()), id: \.offset) { _, card in NativePlayingCard(card: card, width: 64) }
                            }.padding(.vertical, 4)
                        }.scrollIndicators(.hidden)
                    }.foregroundStyle(StudioTheme.onFelt).padding(20).frame(maxWidth: .infinity, alignment: .leading)
                        .background(StudioTheme.felt, in: RoundedRectangle(cornerRadius: StudioTheme.radius))
                    Text(decision.rules.summary + (decision.fromSplit ? " · Split hand" : ""))
                        .font(.caption).foregroundStyle(StudioTheme.muted)
                    Text(decision.topic == .insurance ? "Take insurance?" : "What’s the best play?")
                        .font(.title2.weight(.semibold)).foregroundStyle(StudioTheme.ink)
                    if let choice {
                        StudioCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(choice == decision.recommended ? "Correct" : "Recommended: \(decision.recommended.title)")
                                    .font(.headline).foregroundStyle(choice == decision.recommended ? StudioTheme.accent : StudioTheme.ink)
                                Text("In the session: \(decision.chosen.title)").font(.subheadline).foregroundStyle(StudioTheme.muted)
                                Text(decision.explanation).font(.body).foregroundStyle(StudioTheme.muted)
                            }.accessibilityElement(children: .combine).accessibilityFocused($feedbackFocused)
                        }
                        if choice == decision.recommended {
                            Button(index == decisions.count - 1 ? "Finish review" : "Next decision") { index += 1; self.choice = nil; feedbackFocused = false }
                                .buttonStyle(StudioPrimaryButton()).accessibilityIdentifier("simulation.review.next")
                        } else {
                            Button("Try this decision again") { self.choice = nil; feedbackFocused = false }
                                .buttonStyle(StudioPrimaryButton()).accessibilityIdentifier("simulation.review.retry")
                        }
                    } else {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: typeSize.isAccessibilitySize ? 1 : 2), spacing: 10) {
                            ForEach(decision.availableChoices, id: \.self) { move in
                                Button { choice = move; feedbackFocused = true } label: {
                                    Text(move.title).font(.headline).fixedSize(horizontal: false, vertical: true)
                                        .frame(maxWidth: .infinity, minHeight: 52).padding(8)
                                        .foregroundStyle(StudioTheme.ink).background(StudioTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(StudioTheme.line))
                                }.buttonStyle(.plain).accessibilityIdentifier("simulation.review.choice.\(move.rawValue)")
                            }
                        }
                    }
                    Text("Review does not change your session score.").font(.caption).foregroundStyle(StudioTheme.muted)
                } else {
                    Label("Review complete", systemImage: "checkmark.circle").font(.title2.weight(.semibold)).foregroundStyle(StudioTheme.ink)
                    Text("Try a new session to check what you remember.").font(.body).foregroundStyle(StudioTheme.muted)
                    Button("Back to results") { dismiss() }.buttonStyle(StudioPrimaryButton())
                }
            }.padding(20).frame(maxWidth: 650).frame(maxWidth: .infinity)
        }.background(StudioTheme.background).navigationTitle("Decision review").navigationBarTitleDisplayMode(.inline)
    }
}
