import SwiftUI
import TrainingCore

struct LearnScreen: View {
    let hasPro: Bool
    let completedLessons: Set<String>
    let onComplete: (String) -> Void
    let onUpgrade: () -> Void
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var selectedLesson: Lesson?
    private var completedCount: Int { Curriculum.lessons.filter { completedLessons.contains($0.id) }.count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("\(completedCount) of \(Curriculum.lessons.count) completed")
                            .font(.subheadline).foregroundStyle(TrainingStyle.secondary)
                        ProgressView(value: Double(completedCount), total: Double(Curriculum.lessons.count))
                            .tint(TrainingStyle.accent).accessibilityLabel("Lessons completed")
                    }.padding(.horizontal, 4)
                    NavigationLink {
                        StrategyReferenceScreen()
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "square.grid.3x3").font(.title3).foregroundStyle(TrainingStyle.accent)
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Strategy guide").font(.headline).foregroundStyle(TrainingStyle.ink)
                                Text("Hard hands, soft hands, and pairs").font(.subheadline).foregroundStyle(TrainingStyle.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(TrainingStyle.secondary)
                        }.padding(16).background(TrainingStyle.surface, in: RoundedRectangle(cornerRadius: TrainingStyle.radius))
                    }.buttonStyle(.plain).accessibilityIdentifier("learn.strategy-guide")
                    VStack(spacing: 0) {
                        ForEach(Array(Curriculum.lessons.enumerated()), id: \.element.id) { index, lesson in
                            lessonRow(lesson, index: index)
                            if index < Curriculum.lessons.count - 1 {
                                Divider().overlay(TrainingStyle.border).padding(.leading, textSize.isAccessibilitySize ? 16 : 60)
                            }
                        }
                    }.background(TrainingStyle.surface, in: RoundedRectangle(cornerRadius: TrainingStyle.radius))
                }.padding(20).frame(maxWidth: 650)
                    .frame(maxWidth: .infinity)
            }
            .background(TrainingStyle.background).navigationTitle("Lessons")
            .sheet(item: $selectedLesson) { lesson in
                LessonReader(lesson: lesson) { onComplete(lesson.id) }
            }
        }.tint(TrainingStyle.accent)
    }
    private func lessonRow(_ lesson: Lesson, index: Int) -> some View {
        let completed = completedLessons.contains(lesson.id)
        let locked = lesson.isPremium && !hasPro
        return Button {
            if locked { onUpgrade() } else { selectedLesson = lesson }
        } label: {
            HStack(alignment: .top, spacing: 14) {
                if !textSize.isAccessibilitySize {
                    Text(String(format: "%02d", index + 1)).font(.subheadline.monospacedDigit())
                        .foregroundStyle(TrainingStyle.secondary).frame(width: 30, alignment: .leading).padding(.top, 2)
                }
                VStack(alignment: .leading, spacing: 5) {
                    if textSize.isAccessibilitySize {
                        Text("Lesson \(index + 1)").font(.caption).foregroundStyle(TrainingStyle.secondary)
                    }
                    Text(lesson.title)
                        .font(.body.weight(.medium)).foregroundStyle(TrainingStyle.ink)
                        .multilineTextAlignment(.leading)
                    Text(lesson.subtitle).font(.subheadline).foregroundStyle(TrainingStyle.secondary).multilineTextAlignment(.leading)
                    Text(lesson.durationLabel + (locked ? " · Pro" : completed ? " · Completed" : ""))
                        .font(.caption).foregroundStyle(TrainingStyle.secondary).multilineTextAlignment(.leading)
                }
                if !textSize.isAccessibilitySize {
                    Spacer(minLength: 0)
                    Image(systemName: locked ? "lock.fill" : completed ? "checkmark.circle.fill" : "chevron.right")
                        .font(.caption.weight(.semibold)).foregroundStyle(completed ? TrainingStyle.accent : TrainingStyle.secondary).padding(.top, 4)
                }
            }.padding(16).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
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
                    ProgressView(value: completed ? 1 : Double(step) / Double(totalSteps)).tint(TrainingStyle.accent)
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
                    .padding(20).background(TrainingStyle.background)
            }
        }.tint(TrainingStyle.accent)
    }
    private var teachingStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("\(step + 1) of \(lesson.steps.count)").font(.subheadline).foregroundStyle(TrainingStyle.secondary)
            LessonIllustration(visual: lesson.visual).frame(maxWidth: .infinity).frame(minHeight: 190)
                .background(TrainingStyle.felt, in: RoundedRectangle(cornerRadius: TrainingStyle.radius))
                .accessibilityHidden(true)
            Text(lesson.steps[step].title).font(.title2.bold()).foregroundStyle(TrainingStyle.ink).fixedSize(horizontal: false, vertical: true)
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
            Text("Question \(questionIndex + 1) of \(lesson.questions.count)").font(.subheadline).foregroundStyle(TrainingStyle.secondary)
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
                            .background(selectedAnswer != nil && index == question.correctIndex ? TrainingStyle.soft : TrainingStyle.surface, in: RoundedRectangle(cornerRadius: TrainingStyle.radius))
                            .overlay(RoundedRectangle(cornerRadius: TrainingStyle.radius).strokeBorder(selectedAnswer == index ? TrainingStyle.accent : TrainingStyle.border, lineWidth: 1))
                    }.buttonStyle(.plain).disabled(selectedAnswer != nil)
                        .accessibilityAddTraits(selectedAnswer == index ? .isSelected : [])
                }
            }
            if let selectedAnswer {
                VStack(alignment: .leading, spacing: 8) {
                    Label(selectedAnswer == question.correctIndex ? "Correct" : "Review the answer", systemImage: selectedAnswer == question.correctIndex ? "checkmark.circle" : "info.circle")
                        .font(.headline)
                    Text(question.explanation).font(.subheadline).lineSpacing(3)
                }.foregroundStyle(TrainingStyle.ink).padding(.vertical, 8).frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
            }
        }
    }
    private var completion: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 44)).foregroundStyle(TrainingStyle.accent).accessibilityHidden(true)
            Text("Lesson complete").font(.title2.bold()).foregroundStyle(TrainingStyle.ink).multilineTextAlignment(.center)
            Text(lesson.title).font(.subheadline).foregroundStyle(TrainingStyle.secondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.vertical, 35)
    }
    private func saveCompletion() { guard !completionSaved else { return }; completionSaved = true; onComplete() }
}

private struct LessonIllustration: View {
    let visual: LessonVisual
    @Environment(\.dynamicTypeSize) private var textSize
    var body: some View {
        Group {
            switch visual {
            case .values:
                let layout = textSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16)) : AnyLayout(HStackLayout(spacing: 16))
                layout {
                    miniCard("5", suit: "♥", label: "+1")
                    miniCard("8", suit: "♣", label: "0")
                    miniCard("K", suit: "♠", label: "−1")
                }
            case .cancellation:
                let layout = textSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 18)) : AnyLayout(HStackLayout(spacing: 18))
                layout { miniCard("3", suit: "♣", label: "+1"); Text("+").font(.title); miniCard("Q", suit: "♥", label: "−1"); Text("= 0").font(.title.bold()) }
            case .running:
                VStack(spacing: 18) {
                    Image(systemName: "plus.forwardslash.minus").font(.system(size: 35, weight: .light))
                    if textSize.isAccessibilitySize {
                        Text("0\n↓\n+1\n↓\n0\n↓\n+1").font(.title2.monospacedDigit().weight(.semibold)).multilineTextAlignment(.center)
                    } else {
                        Text("0 → +1 → 0 → +1").font(.title2.monospacedDigit().weight(.semibold))
                    }
                }
            case .shoe:
                HStack(spacing: -30) { ForEach(0..<4) { index in TrainingCardFace(card: TrainingCard(rank: ["3","K","5","A"][index], suit: ["♣","♥","♠","♦"][index]), width: 69).rotationEffect(.degrees(Double(index - 2) * 7)) } }
            case .stacks:
                HStack(alignment: .bottom, spacing: 18) { ForEach(1...3, id: \.self) { count in VStack(spacing: 8) { RoundedRectangle(cornerRadius: 7).fill(StudioTheme.cardPaper).frame(width: 48, height: CGFloat(count * 27)); Text("\(count)").font(.caption.weight(.semibold)) } } }
            case .division:
                VStack(spacing: 10) {
                    Text(textSize.isAccessibilitySize ? "+6\n÷ 3\n= +2" : "+6 ÷ 3 = +2").font(.title.weight(.semibold)).multilineTextAlignment(.center)
                    Text("Running ÷ Decks = True").font(.caption).multilineTextAlignment(.center)
                }
            case .decisions:
                VStack(spacing: 15) { Image(systemName: "square.grid.3x3").font(.system(size: 44, weight: .light)); Text("Basic strategy").font(.subheadline.weight(.medium)) }
            case .boundaries:
                VStack(spacing: 15) { Image(systemName: "checkmark.shield").font(.system(size: 55, weight: .ultraLight)); Text("Simulation only.").font(.headline) }
            }
        }.foregroundStyle(TrainingStyle.onFelt).padding(18)
    }
    private func miniCard(_ rank: String, suit: String, label: String) -> some View {
        let layout = textSize.isAccessibilitySize ? AnyLayout(HStackLayout(spacing: 16)) : AnyLayout(VStackLayout(spacing: 9))
        return layout { TrainingCardFace(card: TrainingCard(rank: rank, suit: suit), width: 53); Text(label).font(.title3.weight(.semibold).monospacedDigit()) }
    }
}
