import SwiftUI
import StudioCore
import BlackjackCore

struct OnboardingScreen: View {
    @EnvironmentObject private var model: StudioModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var step = 0

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    let headerLayout = typeSize.isAccessibilitySize && step == 0
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                        : AnyLayout(HStackLayout(spacing: 12))
                    headerLayout {
                        if step == 1 {
                            Button {
                                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { step = 0 }
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.body.weight(.semibold))
                                    .frame(minWidth: 44, minHeight: 44)
                                    .contentShape(Rectangle())
                            }
                            .accessibilityLabel("Back to introduction")
                        } else {
                            Text("Blackjack Studio").font(.subheadline.weight(.semibold))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if !typeSize.isAccessibilitySize || step == 1 { Spacer(minLength: 0) }
                        Text("\(step + 1) of 2")
                            .font(.subheadline.monospacedDigit()).foregroundStyle(StudioTheme.muted)
                            .fixedSize()
                            .accessibilityLabel("Step \(step + 1) of 2")
                    }
                    .frame(minHeight: 44)

                    if step == 0 { introduction } else { personalize }
                    Spacer(minLength: 8)

                    Button {
                        StudioHaptics.tap(enabled: model.snapshot.preferences.haptics)
                        if step == 0 {
                            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { step = 1 }
                        } else {
                            model.completeOnboarding()
                        }
                    } label: {
                        Text(step == 0 ? "Continue" : "Start training")
                    }
                    .buttonStyle(StudioPrimaryButton())
                    .accessibilityIdentifier("onboardingContinue")

                    Text("Practice only. Never use the app while gambling. Laws and venue rules vary.")
                        .font(.footnote).foregroundStyle(StudioTheme.muted)
                        .multilineTextAlignment(.center).frame(maxWidth: .infinity)
                }
                .padding(24)
                .frame(maxWidth: 560)
                .frame(minHeight: geometry.size.height, alignment: .top)
                .frame(maxWidth: .infinity)
            }
            .background(StudioTheme.background)
            .foregroundStyle(StudioTheme.ink)
            .tint(StudioTheme.accent)
        }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Learn card counting")
                    .font(.largeTitle.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text("Learn Hi-Lo, practice basic strategy, and test both at the table.")
                    .font(.body).foregroundStyle(StudioTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 22) {
                Text("Every card has a value").font(.headline)
                let exampleLayout = typeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 24))
                    : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
                exampleLayout {
                    countExample(Card(rank: .five, suit: .clubs), value: "+1", ranks: "2–6", label: "2 through 6: add 1")
                    countExample(Card(rank: .seven, suit: .hearts), value: "0", ranks: "7–9", label: "7 through 9: no change")
                    countExample(Card(rank: .ace, suit: .spades), value: "−1", ranks: "10–A", label: "10, face cards, and aces: subtract 1")
                }
                Divider().overlay(StudioTheme.line)
                Text("Add each value to your running count.")
                    .font(.subheadline).foregroundStyle(StudioTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
            .background(StudioTheme.surface, in: RoundedRectangle(cornerRadius: StudioTheme.radius))

            Text("Free lessons and drills to get started. Train offline, at your own pace.")
                .font(.subheadline).foregroundStyle(StudioTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func countExample(_ card: Card, value: String, ranks: String, label: String) -> some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(HStackLayout(spacing: 20))
            : AnyLayout(VStackLayout(spacing: 10))
        return layout {
            NativePlayingCard(card: card, width: 58).accessibilityHidden(true)
            VStack(alignment: typeSize.isAccessibilitySize ? .leading : .center, spacing: 8) {
                Text(value).font(.title2.weight(.semibold)).monospacedDigit()
                Text(ranks).font(.caption).foregroundStyle(StudioTheme.muted)
            }
            .fixedSize(horizontal: false, vertical: true)
            if typeSize.isAccessibilitySize { Spacer(minLength: 0) }
        }
        .frame(maxWidth: .infinity, alignment: typeSize.isAccessibilitySize ? .leading : .center)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }

    private var personalize: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Where are you starting?")
                .font(.largeTitle.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 0) {
                ForEach(Experience.allCases, id: \.self) { experience in
                    Button { model.snapshot.preferences.experience = experience } label: {
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(experience.title).font(.headline)
                                Text(experienceDescription(experience))
                                    .font(.subheadline).foregroundStyle(StudioTheme.muted)
                            }
                            .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                            Image(systemName: model.snapshot.preferences.experience == experience ? "checkmark.circle.fill" : "circle")
                                .font(.title2)
                                .foregroundStyle(model.snapshot.preferences.experience == experience ? StudioTheme.accent : StudioTheme.muted)
                                .accessibilityHidden(true)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .padding(16)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(model.snapshot.preferences.experience == experience ? .isSelected : [])
                    if experience != Experience.allCases.last {
                        Divider().overlay(StudioTheme.line).padding(.leading, 16)
                    }
                }
            }
            .background(StudioTheme.surface, in: RoundedRectangle(cornerRadius: StudioTheme.radius))

            VStack(alignment: .leading, spacing: 12) {
                Text("Daily practice").font(.headline).accessibilityAddTraits(.isHeader)
                let layout = typeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(spacing: 10))
                    : AnyLayout(HStackLayout(spacing: 10))
                layout {
                    ForEach([3, 5, 10], id: \.self) { minutes in
                        Button { model.snapshot.preferences.dailyMinutes = minutes } label: {
                            Text("\(minutes) min")
                                .font(.headline).monospacedDigit()
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .padding(.horizontal, 8)
                                .foregroundStyle(model.snapshot.preferences.dailyMinutes == minutes ? StudioTheme.buttonText : StudioTheme.ink)
                                .background(model.snapshot.preferences.dailyMinutes == minutes ? StudioTheme.buttonFill : StudioTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(minutes) minutes per day")
                        .accessibilityAddTraits(model.snapshot.preferences.dailyMinutes == minutes ? .isSelected : [])
                    }
                }
            }
        }
    }

    private func experienceDescription(_ experience: Experience) -> String {
        switch experience {
        case .starting: return "Learn the card values and running count."
        case .familiar: return "Practice keeping an accurate count."
        case .refining: return "Work on speed and true count."
        }
    }
}
