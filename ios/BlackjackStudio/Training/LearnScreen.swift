import SwiftUI
import TrainingCore

struct LearnScreen: View {
    let hasPro: Bool
    let completedLessons: Set<String>
    let onComplete: (String) -> Void
    let onUpgrade: () -> Void
    @State private var selectedLesson: Lesson?
    private var completedCount: Int { Curriculum.lessons.filter { completedLessons.contains($0.id) }.count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    introduction
                    NavigationLink {
                        StrategyReferenceScreen()
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "square.grid.3x3").font(.title2).foregroundStyle(TrainingStyle.ink)
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Strategy guide").font(.headline).foregroundStyle(TrainingStyle.ink)
                                Text("Hard hands, soft hands, and pairs.").font(.caption).foregroundStyle(TrainingStyle.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(TrainingStyle.secondary)
                        }.padding(20).background(TrainingStyle.soft, in: RoundedRectangle(cornerRadius: 22))
                    }.buttonStyle(.plain).accessibilityIdentifier("learn.strategy-guide")
                    VStack(spacing: 11) {
                        ForEach(Array(Curriculum.lessons.enumerated()), id: \.element.id) { index, lesson in
                            lessonRow(lesson, index: index)
                        }
                    }
                    Label("Practice with simulated cards, away from live play.", systemImage: "checkmark.shield")
                        .font(.footnote).foregroundStyle(TrainingStyle.secondary).fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 5)
                }.padding(20).frame(maxWidth: 650)
                    .frame(maxWidth: .infinity)
            }
            .background(TrainingStyle.background).navigationTitle("Learn")
            .sheet(item: $selectedLesson) { lesson in
                LessonReader(lesson: lesson) { onComplete(lesson.id) }
            }
        }.tint(TrainingStyle.ink)
    }
    private var introduction: some View {
        HStack(alignment: .center, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Text("One skill.\nA strong foundation.").font(.title2.bold()).foregroundStyle(TrainingStyle.ink)
                Text("Eight short lessons. A better instinct.").font(.subheadline).foregroundStyle(TrainingStyle.secondary)
            }
            Spacer(minLength: 0)
            ZStack {
                Circle().stroke(TrainingStyle.border, lineWidth: 7)
                Circle().trim(from: 0, to: Double(completedCount) / Double(Curriculum.lessons.count))
                    .stroke(TrainingStyle.ink, style: StrokeStyle(lineWidth: 7, lineCap: .round)).rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text("\(completedCount)").font(.title2.bold().monospacedDigit())
                    Text("OF 8").font(.caption2.weight(.medium)).tracking(1)
                }.foregroundStyle(TrainingStyle.ink)
            }.frame(width: 78, height: 78)
                .accessibilityElement(children: .ignore).accessibilityLabel("\(completedCount) of 8 lessons completed")
        }.padding(5)
    }
    private func lessonRow(_ lesson: Lesson, index: Int) -> some View {
        let completed = completedLessons.contains(lesson.id)
        let locked = lesson.isPremium && !hasPro
        return Button {
            if locked { onUpgrade() } else { selectedLesson = lesson }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 15).fill(completed ? TrainingStyle.lime : TrainingStyle.soft)
                    Image(systemName: completed ? "checkmark" : lesson.symbol)
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(completed ? TrainingStyle.forest : TrainingStyle.ink)
                }.frame(width: 48, height: 52)
                VStack(alignment: .leading, spacing: 5) {
                    Text(String(format: "%02d  %@", index + 1, lesson.title))
                        .font(.subheadline.weight(.semibold)).foregroundStyle(TrainingStyle.ink)
                        .multilineTextAlignment(.leading)
                    Text(lesson.subtitle).font(.caption).foregroundStyle(TrainingStyle.secondary).multilineTextAlignment(.leading)
                    HStack(spacing: 5) {
                        Text(lesson.durationLabel)
                        if locked { Text("·"); Text("PRO").fontWeight(.semibold) }
                        if completed { Text("· Completed") }
                    }.font(.caption2).foregroundStyle(TrainingStyle.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: locked ? "lock.fill" : "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(TrainingStyle.secondary)
            }.padding(15).frame(maxWidth: .infinity, alignment: .leading)
                .background(TrainingStyle.surface, in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(TrainingStyle.border, lineWidth: 1))
        }.buttonStyle(.plain)
            .accessibilityLabel("Lesson \(index + 1), \(lesson.title), \(completed ? "completed" : locked ? "Pro lesson" : "available")")
            .accessibilityHint(locked ? "Opens the Pro upgrade" : "Opens the lesson")
    }
}

private struct LessonReader: View {
    let lesson: Lesson
    let onComplete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = 0
    @State private var selectedAnswer: Int?
    @State private var completed = false
    @State private var completionSaved = false
    private var isQuiz: Bool { step >= lesson.steps.count }
    private var questionIndex: Int { step - lesson.steps.count }
    private var totalSteps: Int { lesson.steps.count + lesson.questions.count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ProgressView(value: completed ? 1 : Double(step) / Double(totalSteps)).tint(TrainingStyle.ink)
                        .accessibilityLabel("Lesson progress")
                    if completed { completion }
                    else if isQuiz { question }
                    else { teachingStep }
                }.padding(24).frame(maxWidth: 600).frame(maxWidth: .infinity)
            }
            .background(TrainingStyle.background)
            .navigationTitle(lesson.title).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if step > 0 && !completed {
                        Button("Previous", systemImage: "chevron.left") { step -= 1; selectedAnswer = nil }
                            .labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark") { dismiss() }.labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    if completed { saveCompletion(); dismiss(); return }
                    let advance = {
                        if step == totalSteps - 1 { completed = true; saveCompletion() }
                        else { step += 1; selectedAnswer = nil }
                    }
                    if reduceMotion { advance() } else { withAnimation(.easeInOut(duration: 0.2)) { advance() } }
                } label: {
                    HStack { Text(completed ? "Done" : isQuiz && selectedAnswer == nil ? "Choose an answer" : "Continue"); if !completed { Image(systemName: "arrow.right") } }
                }.buttonStyle(TrainingPrimaryButton()).disabled(isQuiz && selectedAnswer == nil && !completed)
                    .opacity(isQuiz && selectedAnswer == nil && !completed ? 0.5 : 1)
                    .padding(20).background(TrainingStyle.background)
            }
        }.tint(TrainingStyle.ink)
    }
    private var teachingStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("THE IDEA · \(step + 1) OF \(lesson.steps.count)").font(.caption.weight(.semibold)).tracking(1).foregroundStyle(TrainingStyle.secondary)
            LessonIllustration(visual: lesson.visual).frame(maxWidth: .infinity).frame(minHeight: 190)
                .background(TrainingStyle.forest, in: RoundedRectangle(cornerRadius: 26))
                .accessibilityHidden(true)
            Text(lesson.steps[step].title).font(.largeTitle.bold()).foregroundStyle(TrainingStyle.ink).fixedSize(horizontal: false, vertical: true)
            Text(lesson.steps[step].body).font(.body).foregroundStyle(TrainingStyle.secondary).lineSpacing(5)
            if !lesson.steps[step].detail.isEmpty {
                Text(lesson.steps[step].detail).font(.headline.monospacedDigit()).foregroundStyle(TrainingStyle.ink)
                    .padding(18).frame(maxWidth: .infinity, alignment: .leading).background(TrainingStyle.soft, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }
    private var question: some View {
        let question = lesson.questions[questionIndex]
        return VStack(alignment: .leading, spacing: 20) {
            TrainingPill(text: "QUICK CHECK \(questionIndex + 1) OF \(lesson.questions.count)", symbol: "sparkle")
            Text(question.prompt).font(.title2.bold()).foregroundStyle(TrainingStyle.ink).fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 12) {
                ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                    Button { guard selectedAnswer == nil else { return }; selectedAnswer = index } label: {
                        HStack(spacing: 14) {
                            Text(option).font(.body.weight(.medium)).multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                            if selectedAnswer != nil && index == question.correctIndex { Image(systemName: "checkmark.circle.fill") }
                            else if selectedAnswer == index { Image(systemName: "xmark.circle") }
                            else { Image(systemName: "circle").foregroundStyle(TrainingStyle.border) }
                        }.foregroundStyle(TrainingStyle.ink).padding(18).frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                            .background(selectedAnswer != nil && index == question.correctIndex ? TrainingStyle.soft : TrainingStyle.surface, in: RoundedRectangle(cornerRadius: 18))
                            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(selectedAnswer == index ? TrainingStyle.ink : TrainingStyle.border, lineWidth: 1))
                    }.buttonStyle(.plain).disabled(selectedAnswer != nil)
                        .accessibilityAddTraits(selectedAnswer == index ? .isSelected : [])
                }
            }
            if let selectedAnswer {
                VStack(alignment: .leading, spacing: 8) {
                    Label(selectedAnswer == question.correctIndex ? "Exactly." : "Here’s the idea.", systemImage: selectedAnswer == question.correctIndex ? "checkmark.circle" : "lightbulb")
                        .font(.headline)
                    Text(question.explanation).font(.subheadline).lineSpacing(3)
                }.foregroundStyle(TrainingStyle.ink).padding(18).frame(maxWidth: .infinity, alignment: .leading)
                    .background(TrainingStyle.soft, in: RoundedRectangle(cornerRadius: 18))
                    .accessibilityElement(children: .combine)
            }
        }
    }
    private var completion: some View {
        VStack(spacing: 22) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 62)).foregroundStyle(TrainingStyle.ink).padding(30)
                .background(TrainingStyle.soft, in: Circle())
            Text("One skill stronger.").font(.largeTitle.bold()).foregroundStyle(TrainingStyle.ink).multilineTextAlignment(.center)
            Text("\(lesson.title) · Completed").font(.subheadline).foregroundStyle(TrainingStyle.secondary)
            Text("A short practice session will help it stick.").font(.body).foregroundStyle(TrainingStyle.secondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.vertical, 35)
    }
    private func saveCompletion() { guard !completionSaved else { return }; completionSaved = true; onComplete() }
}

private struct LessonIllustration: View {
    let visual: LessonVisual
    var body: some View {
        Group {
            switch visual {
            case .values:
                HStack(spacing: 16) {
                    miniCard("5", suit: "♥", label: "+1")
                    miniCard("8", suit: "♣", label: "0")
                    miniCard("K", suit: "♠", label: "−1")
                }
            case .cancellation:
                HStack(spacing: 18) { miniCard("3", suit: "♣", label: "+1"); Text("+").font(.title); miniCard("Q", suit: "♥", label: "−1"); Text("= 0").font(.title.bold()) }
            case .running:
                VStack(spacing: 18) { Image(systemName: "plus.forwardslash.minus").font(.system(size: 35, weight: .light)); Text("0 → +1 → 0 → +1").font(.title2.monospacedDigit().weight(.semibold)) }
            case .shoe:
                HStack(spacing: -30) { ForEach(0..<4) { index in TrainingCardFace(card: TrainingCard(rank: ["3","K","5","A"][index], suit: ["♣","♥","♠","♦"][index]), width: 69).rotationEffect(.degrees(Double(index - 2) * 7)) } }
            case .stacks:
                HStack(alignment: .bottom, spacing: 18) { ForEach(1...3, id: \.self) { count in VStack(spacing: 8) { RoundedRectangle(cornerRadius: 7).fill(TrainingStyle.lime.opacity(0.75)).frame(width: 48, height: CGFloat(count * 27)); Text("\(count)").font(.caption.weight(.semibold)) } } }
            case .division:
                VStack(spacing: 10) { Text("+6 ÷ 3 = +2").font(.system(size: 32, weight: .semibold, design: .rounded)); Text("RUNNING   ÷   DECKS   =   TRUE").font(.caption2).tracking(1) }
            case .decisions:
                VStack(spacing: 15) { Image(systemName: "scope").font(.system(size: 55, weight: .ultraLight)); Text("Better decisions. Every hand.").font(.subheadline.weight(.medium)) }
            case .boundaries:
                VStack(spacing: 15) { Image(systemName: "checkmark.shield").font(.system(size: 55, weight: .ultraLight)); Text("Simulation only.").font(.headline) }
            }
        }.foregroundStyle(TrainingStyle.lime).padding(18)
    }
    private func miniCard(_ rank: String, suit: String, label: String) -> some View {
        VStack(spacing: 9) { TrainingCardFace(card: TrainingCard(rank: rank, suit: suit), width: 53); Text(label).font(.title3.weight(.semibold).monospacedDigit()) }
    }
}
