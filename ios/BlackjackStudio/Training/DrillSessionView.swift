import SwiftUI
import UIKit
import TrainingCore

struct DrillSessionView: View {
    let kind: DrillKind
    let onFinish: (DrillSummary) -> Void
    var hapticsEnabled = true
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var textSize
    @AccessibilityFocusState private var feedbackFocused: Bool
    @State private var session: DrillSession
    @State private var answer = ""
    @State private var paused = false
    @State private var confirmingExit = false
    @State private var promptStarted = ProcessInfo.processInfo.systemUptime
    @State private var elapsedBeforePause: Double = 0
    @State private var saved = false
    @State private var reviewingMistakes = false

    init(kind: DrillKind, onFinish: @escaping (DrillSummary) -> Void, hapticsEnabled: Bool = true) {
        self.kind = kind; self.onFinish = onFinish; self.hapticsEnabled = hapticsEnabled
        _session = State(initialValue: DrillSession(kind: kind))
    }
    private var parsedAnswer: Double? { Double(answer) }

    var body: some View {
        NavigationStack {
            ZStack {
                TrainingStyle.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 24) {
                        if session.isComplete { result }
                        else if let prompt = session.currentPrompt { exercise(prompt) }
                    }.padding(20).frame(maxWidth: 600).frame(maxWidth: .infinity)
                }.accessibilityHidden(paused).blur(radius: paused ? 18 : 0).allowsHitTesting(!paused)
                if paused { pauseOverlay }
            }
            .navigationTitle(kind.title).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { session.isComplete ? finish() : showExit() } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }
                        .accessibilityLabel(session.isComplete ? "Save and close session" : "End session")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !session.isComplete {
                        Button { paused ? resume() : pause() } label: { Image(systemName: paused ? "play.fill" : "pause.fill").frame(width: 44, height: 44) }
                            .accessibilityLabel(paused ? "Resume session" : "Pause session")
                    }
                }
            }
            .confirmationDialog("End this session?", isPresented: $confirmingExit, titleVisibility: .visible) {
                Button("End session", role: .destructive) { dismiss() }
                Button("Keep practicing", role: .cancel) { resume() }
            } message: { Text("This unfinished session won’t be saved.") }
            .onChange(of: scenePhase) { _, phase in if phase != .active && !session.isComplete { pause() } }
            .onAppear { promptStarted = ProcessInfo.processInfo.systemUptime }
            .onChange(of: session.currentResponse?.id) { _, responseID in
                feedbackFocused = responseID != nil
            }
            .sheet(isPresented: $reviewingMistakes) { MistakeReview(summary: session.summary()) }
        }.tint(TrainingStyle.ink).interactiveDismissDisabled(!session.isComplete)
    }
    private func exercise(_ prompt: DrillPrompt) -> some View {
        VStack(spacing: 22) {
            VStack(spacing: 10) {
                HStack {
                    Text("\(session.index + 1) of \(session.prompts.count)").font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(session.correct) correct").font(.subheadline)
                }.foregroundStyle(TrainingStyle.secondary)
                ProgressView(value: Double(session.responses.count), total: Double(session.prompts.count)).tint(TrainingStyle.ink)
                    .accessibilityLabel("Questions answered")
            }
            if kind == .runningCount || kind == .fullDeck {
                Text(session.index == 0 ? "Start at zero." : "Keep the count from the previous cards.")
                    .font(.subheadline).foregroundStyle(TrainingStyle.secondary).multilineTextAlignment(.center)
            }
            promptVisual(prompt)
            if let response = session.currentResponse { feedback(response) }
            else {
                Text(kind.answerLabel).font(.title3.bold()).foregroundStyle(TrainingStyle.ink).multilineTextAlignment(.center)
                answerControls
                if kind == .trueCount {
                    Text("Drop the decimal toward zero.").font(.footnote).foregroundStyle(TrainingStyle.secondary)
                } else if kind == .deckEstimation {
                    Text("Estimate to the nearest half deck.").font(.footnote).foregroundStyle(TrainingStyle.secondary)
                }
            }
        }
    }
    @ViewBuilder private func promptVisual(_ prompt: DrillPrompt) -> some View {
        switch kind {
        case .cardValues, .pairs, .runningCount, .fullDeck:
            VStack(spacing: 20) {
                HStack(spacing: kind == .fullDeck ? -13 : 17) {
                    ForEach(Array(prompt.cards.enumerated()), id: \.offset) { _, card in
                        TrainingCardFace(card: card, width: kind == .fullDeck ? 73 : 89)
                    }
                }.padding(.vertical, 8)
                if kind == .fullDeck {
                    Text("\(prompt.cardsSeen) / 52 CARDS").font(.caption2.weight(.medium)).tracking(2).foregroundStyle(TrainingStyle.lime.opacity(0.85))
                }
            }.padding(.vertical, 26).frame(maxWidth: .infinity)
                .background(TrainingStyle.forest, in: RoundedRectangle(cornerRadius: 26))
                .accessibilityElement(children: .contain).accessibilityLabel(kind == .fullDeck ? "Next four simulated cards" : "Simulated cards")
        case .trueCount:
            HStack(spacing: 18) {
                numberPanel(DrillPrompt.format(Double(prompt.runningCount ?? 0), signed: true), label: "RUNNING")
                Text("÷").font(.system(size: 36, weight: .light)).foregroundStyle(TrainingStyle.lime.opacity(0.6)).accessibilityLabel("divided by")
                numberPanel(DrillPrompt.format(prompt.decksRemaining ?? 1), label: "DECKS LEFT")
            }.padding(.horizontal, 24).padding(.vertical, 35).frame(maxWidth: .infinity)
                .background(TrainingStyle.forest, in: RoundedRectangle(cornerRadius: 26))
                .accessibilityElement(children: .combine)
        case .deckEstimation:
            DeckStackIllustration(decks: prompt.decksRemaining ?? 1)
        }
    }
    private func numberPanel(_ value: String, label: String) -> some View {
        VStack(spacing: 12) {
            Text(value).font(.system(.largeTitle, design: .rounded).weight(.semibold)).monospacedDigit().foregroundStyle(TrainingStyle.lime).minimumScaleFactor(0.7)
            Text(label).font(.caption2.weight(.medium)).tracking(1).foregroundStyle(TrainingStyle.lime.opacity(0.85))
        }.frame(maxWidth: .infinity)
    }
    @ViewBuilder private var answerControls: some View {
        if kind == .cardValues || kind == .pairs {
            let values = kind == .cardValues ? [-1, 0, 1] : [-2, -1, 0, 1, 2]
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: textSize.isAccessibilitySize ? 2 : values.count), spacing: 9) {
                ForEach(values, id: \.self) { value in
                    Button { submit(Double(value)) } label: {
                        Text(DrillPrompt.format(Double(value), signed: true)).font(.title2.weight(.semibold).monospacedDigit())
                            .frame(maxWidth: .infinity, minHeight: 70)
                            .background(TrainingStyle.surface, in: RoundedRectangle(cornerRadius: 18))
                            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(TrainingStyle.border))
                    }.buttonStyle(.plain).foregroundStyle(TrainingStyle.ink).accessibilityLabel("Answer \(value)")
                }
            }
        } else if kind == .deckEstimation {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(1...12, id: \.self) { half in
                    let value = Double(half) / 2
                    Button { submit(value) } label: {
                        Text(DrillPrompt.format(value)).font(.title3.weight(.medium).monospacedDigit())
                            .frame(maxWidth: .infinity, minHeight: 51)
                            .background(TrainingStyle.surface, in: RoundedRectangle(cornerRadius: 15))
                            .overlay(RoundedRectangle(cornerRadius: 15).strokeBorder(TrainingStyle.border))
                    }.buttonStyle(.plain).foregroundStyle(TrainingStyle.ink).accessibilityLabel("\(DrillPrompt.format(value)) decks")
                }
            }
        } else {
            VStack(spacing: 13) {
                Text(answer.isEmpty ? "—" : answer.replacingOccurrences(of: "-", with: "−"))
                    .font(.system(size: 36, weight: .medium, design: .rounded)).monospacedDigit()
                    .foregroundStyle(answer.isEmpty ? TrainingStyle.secondary : TrainingStyle.ink)
                    .frame(maxWidth: .infinity, minHeight: 65).background(TrainingStyle.surface, in: RoundedRectangle(cornerRadius: 19))
                    .overlay(RoundedRectangle(cornerRadius: 19).strokeBorder(TrainingStyle.border))
                    .accessibilityLabel("Your answer: \(answer.isEmpty ? "empty" : answer)")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 9) {
                    ForEach(1...9, id: \.self) { value in keypadButton(String(value)) { appendDigit(value) } }
                    keypadButton("±", label: "Change sign") {
                        if answer.hasPrefix("-") { answer.removeFirst() } else { answer = "-" + answer }
                    }
                    keypadButton("0") { appendDigit(0) }
                    Button { if !answer.isEmpty { answer.removeLast() } } label: {
                        Image(systemName: "delete.left").font(.title3).frame(maxWidth: .infinity, minHeight: 47)
                    }.foregroundStyle(TrainingStyle.ink).buttonStyle(.plain).accessibilityLabel("Delete last digit")
                }
                Button { if let parsedAnswer { submit(parsedAnswer) } } label: { Label("Check count", systemImage: "checkmark") }
                    .buttonStyle(TrainingPrimaryButton()).disabled(parsedAnswer == nil).opacity(parsedAnswer == nil ? 0.45 : 1)
            }
        }
    }
    private func keypadButton(_ text: String, label: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text).font(.title2.weight(.regular)).monospacedDigit().frame(maxWidth: .infinity, minHeight: 47)
                .background(TrainingStyle.surface, in: RoundedRectangle(cornerRadius: 14))
        }.foregroundStyle(TrainingStyle.ink).buttonStyle(.plain).accessibilityLabel(label ?? text)
    }
    private func appendDigit(_ value: Int) {
        guard answer.filter(\.isNumber).count < 3 else { return }
        if answer == "0" { answer = String(value) }
        else if answer == "-0" { answer = "-" + String(value) }
        else { answer += String(value) }
    }
    private func feedback(_ response: DrillResponse) -> some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: response.correct ? "checkmark.circle.fill" : "lightbulb")
                    Text(response.correct ? "Right on." : "The count is \(response.prompt.formattedAnswer).")
                        .font(.title3.weight(.semibold))
                }.foregroundStyle(response.correct ? TrainingStyle.ink : TrainingStyle.coral)
                Text(response.prompt.explanation).font(.subheadline).foregroundStyle(TrainingStyle.secondary).lineSpacing(4)
                if !response.correct {
                    Text("Your answer: \(DrillPrompt.format(response.answer, signed: kind != .deckEstimation))")
                        .font(.caption).foregroundStyle(TrainingStyle.secondary)
                }
            }.padding(21).frame(maxWidth: .infinity, alignment: .leading)
                .background(TrainingStyle.soft, in: RoundedRectangle(cornerRadius: 22))
                .accessibilityElement(children: .combine)
                .accessibilityFocused($feedbackFocused)
            Button { advance() } label: {
                HStack { Text(session.index == session.prompts.count - 1 ? "See results" : "Next"); Image(systemName: "arrow.right") }
            }.buttonStyle(TrainingPrimaryButton())
        }
    }
    private var pauseOverlay: some View {
        VStack(spacing: 22) {
            Image(systemName: "pause.circle").font(.system(size: 48, weight: .light)).foregroundStyle(TrainingStyle.ink)
            Text("Take your time.").font(.title.bold()).foregroundStyle(TrainingStyle.ink)
            Text("The timer is paused.").font(.subheadline).foregroundStyle(TrainingStyle.secondary)
            Button { resume() } label: { Label("Resume", systemImage: "play.fill") }.buttonStyle(TrainingPrimaryButton())
        }.padding(28).background(TrainingStyle.surface, in: RoundedRectangle(cornerRadius: 26)).padding(24)
            .shadow(color: .black.opacity(0.12), radius: 25, y: 12)
            .accessibilityElement(children: .contain).accessibilityAddTraits(.isModal)
    }
    private var result: some View {
        let summary = session.summary()
        return VStack(spacing: 25) {
            Image(systemName: summary.accuracy >= 0.9 ? "checkmark.seal" : "sparkles")
                .font(.system(size: 54, weight: .light)).foregroundStyle(TrainingStyle.ink)
                .frame(width: 116, height: 116).background(TrainingStyle.soft, in: Circle()).padding(.top, 15)
            VStack(spacing: 9) {
                Text(summary.accuracy == 1 ? "A clean count." : "One session sharper.")
                    .font(.largeTitle.bold()).foregroundStyle(TrainingStyle.ink).multilineTextAlignment(.center)
                Text(summary.nextSuggestion).font(.subheadline).foregroundStyle(TrainingStyle.secondary).multilineTextAlignment(.center)
            }
            HStack(spacing: 12) {
                resultMetric("\(summary.accuracyPercent)%", label: "ACCURACY")
                resultMetric("\(summary.correct)/\(summary.total)", label: "CORRECT")
                resultMetric(String(format: "%.1fs", summary.secondsPerAnswer), label: "PER ANSWER")
            }
            if !summary.mistakes.isEmpty {
                Button { reviewingMistakes = true } label: {
                    HStack { Image(systemName: "arrow.counterclockwise"); Text("Review \(summary.mistakes.count) \(summary.mistakes.count == 1 ? "miss" : "misses")"); Spacer(); Image(systemName: "chevron.right") }
                        .font(.subheadline.weight(.semibold)).padding(20).foregroundStyle(TrainingStyle.ink)
                        .background(TrainingStyle.surface, in: RoundedRectangle(cornerRadius: 18))
                }.buttonStyle(.plain)
            }
            Button { finish() } label: { HStack { Text("Finish session"); Image(systemName: "checkmark") } }.buttonStyle(TrainingPrimaryButton())
            Text("Time reflects active answering. Pauses are excluded.").font(.caption).foregroundStyle(TrainingStyle.secondary).multilineTextAlignment(.center)
        }
    }
    private func resultMetric(_ value: String, label: String) -> some View {
        VStack(spacing: 9) { Text(value).font(.title2.bold().monospacedDigit()).minimumScaleFactor(0.65); Text(label).font(.system(size: 9, weight: .semibold)).tracking(0.5) }
            .foregroundStyle(TrainingStyle.ink).frame(maxWidth: .infinity).padding(.vertical, 22)
            .background(TrainingStyle.surface, in: RoundedRectangle(cornerRadius: 19))
            .accessibilityElement(children: .combine)
    }
    private func submit(_ value: Double) {
        guard !paused else { return }
        let elapsed = elapsedBeforePause + (ProcessInfo.processInfo.systemUptime - promptStarted)
        guard let response = session.submit(answer: value, elapsedSeconds: elapsed) else { return }
        if hapticsEnabled { UINotificationFeedbackGenerator().notificationOccurred(response.correct ? .success : .warning) }
        elapsedBeforePause = 0
    }
    private func advance() {
        let update = {
            _ = session.advance()
            answer = ""
            promptStarted = ProcessInfo.processInfo.systemUptime
            elapsedBeforePause = 0
            if session.isComplete { saveCompletedSession() }
        }
        if reduceMotion { update() } else { withAnimation(.easeInOut(duration: 0.18)) { update() } }
    }
    private func pause() {
        guard !paused else { return }
        if session.currentResponse == nil { elapsedBeforePause += (ProcessInfo.processInfo.systemUptime - promptStarted) }
        paused = true
    }
    private func resume() { promptStarted = ProcessInfo.processInfo.systemUptime; paused = false }
    private func showExit() { pause(); confirmingExit = true }
    private func saveCompletedSession() {
        guard session.isComplete, !saved else { return }
        saved = true
        onFinish(session.summary())
    }
    private func finish() {
        saveCompletedSession()
        dismiss()
    }
}

private struct DeckStackIllustration: View {
    let decks: Double
    var body: some View {
        VStack(spacing: 18) {
            Text("COMPARE THE STACKS").font(.caption2.weight(.medium)).tracking(1.2).foregroundStyle(TrainingStyle.lime.opacity(0.9))
            HStack(alignment: .bottom, spacing: 35) {
                VStack(spacing: 12) {
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 8).strokeBorder(TrainingStyle.lime.opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [4]))
                        RoundedRectangle(cornerRadius: 7).fill(Color(red: 0.94, green: 0.94, blue: 0.86)).frame(height: 180 * decks / 6)
                            .overlay(alignment: .bottom) {
                                VStack(spacing: 2) { ForEach(0..<max(1, Int(decks * 8)), id: \.self) { _ in Rectangle().fill(TrainingStyle.forest.opacity(0.2)).frame(height: 1) } }.padding(.vertical, 2)
                            }
                    }.frame(width: 97, height: 180)
                    Text("ESTIMATE").font(.caption2.weight(.semibold)).tracking(1).foregroundStyle(TrainingStyle.lime)
                }
                VStack(spacing: 12) {
                    ZStack(alignment: .bottom) {
                        Color.clear
                        RoundedRectangle(cornerRadius: 5).fill(TrainingStyle.lime).frame(height: 30)
                    }.frame(width: 62, height: 180)
                    Text("1 DECK").font(.caption2.weight(.semibold)).tracking(1).foregroundStyle(TrainingStyle.lime)
                }
            }
        }.padding(24).frame(maxWidth: .infinity)
            .background(TrainingStyle.forest, in: RoundedRectangle(cornerRadius: 26))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Simulated stack estimation. The stack contains \(Int(decks * 52)) cards. One deck contains 52. Enter the number of decks.")
            .accessibilityHint("A card-count description is provided as a nonvisual alternative to the stack-height exercise.")
    }
}

private struct MistakeReview: View {
    let summary: DrillSummary
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(summary.mistakes) { response in
                        VStack(alignment: .leading, spacing: 13) {
                            Text("CHECK \(response.id + 1)").font(.caption.weight(.semibold)).tracking(1).foregroundStyle(TrainingStyle.secondary)
                            if !response.prompt.cards.isEmpty {
                                HStack(spacing: 9) { ForEach(Array(response.prompt.cards.enumerated()), id: \.offset) { _, card in TrainingCardFace(card: card, width: 45) } }
                            }
                            Text(response.prompt.explanation).font(.body).foregroundStyle(TrainingStyle.ink)
                            HStack { Text("You: \(DrillPrompt.format(response.answer, signed: summary.kind != .deckEstimation))"); Spacer(); Text("Correct: \(response.prompt.formattedAnswer)").fontWeight(.semibold) }
                                .font(.subheadline).foregroundStyle(TrainingStyle.secondary)
                        }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(TrainingStyle.surface, in: RoundedRectangle(cornerRadius: 20))
                    }
                }.padding(20).frame(maxWidth: 600).frame(maxWidth: .infinity)
            }.background(TrainingStyle.background).navigationTitle("Make it stick").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }.tint(TrainingStyle.ink)
    }
}
