import SwiftUI
import StudioCore
import BlackjackCore

struct OnboardingScreen: View {
    @EnvironmentObject private var model: StudioModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = 0
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    HStack {
                        Label("BLACKJACK STUDIO", systemImage: "suit.spade.fill").font(.system(.caption, design: .rounded).weight(.bold)).tracking(1.8)
                        Spacer()
                        Text("\(step + 1) / 2").font(.caption.monospacedDigit()).foregroundStyle(StudioTheme.muted)
                    }.padding(.top, 15)
                    if step == 0 { introduction } else { personalize }
                    Spacer(minLength: 8)
                    Button {
                        StudioHaptics.tap(enabled: model.snapshot.preferences.haptics)
                        if step == 0 { withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { step = 1 } }
                        else { model.completeOnboarding() }
                    } label: {
                        HStack { Text(step == 0 ? "Find your rhythm" : "Start training"); Spacer(); Image(systemName: "arrow.right") }.padding(.horizontal, 22)
                    }.buttonStyle(StudioPrimaryButton()).accessibilityIdentifier("onboardingContinue")
                    Text("Practice only. Never use the app while gambling. Local laws and venue rules vary.")
                        .font(.footnote).foregroundStyle(StudioTheme.muted).multilineTextAlignment(.center).frame(maxWidth: .infinity)
                }.padding(26).frame(maxWidth: 640).frame(minHeight: geometry.size.height, alignment: .top).frame(maxWidth: .infinity)
            }.background(StudioTheme.background).foregroundStyle(StudioTheme.ink)
        }
    }
    private var introduction: some View {
        VStack(alignment: .leading, spacing: 28) {
            ZStack {
                RoundedRectangle(cornerRadius: 36).fill(StudioTheme.forest)
                Circle().stroke(StudioTheme.lime.opacity(0.13), lineWidth: 1).frame(width: 235, height: 235)
                Circle().stroke(StudioTheme.lime.opacity(0.09), lineWidth: 1).frame(width: 180, height: 180)
                HStack(spacing: -16) {
                    NativePlayingCard(card: Card(rank: .five, suit: .clubs), width: 85).rotationEffect(.degrees(-13)).offset(y: 14)
                    NativePlayingCard(card: Card(rank: .ace, suit: .spades), width: 85).rotationEffect(.degrees(8)).offset(y: -13)
                }.accessibilityHidden(true)
                VStack { Spacer(); Text("+1  −1  =  0").font(.system(.caption, design: .monospaced).weight(.medium)).tracking(4).foregroundStyle(StudioTheme.lime).padding(.bottom, 24) }
            }.frame(height: 265)
            Text("A sharper mind.\nOne card at a time.").font(.system(.largeTitle, design: .rounded).weight(.bold)).fixedSize(horizontal: false, vertical: true)
            Text("Learn the count. Build the habit. Practice without stakes.").font(.title3).foregroundStyle(StudioTheme.muted).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 18) {
                Label("Private", systemImage: "lock.shield")
                Label("Offline", systemImage: "wifi.slash")
                Label("At your pace", systemImage: "leaf")
            }.font(.caption).foregroundStyle(StudioTheme.muted).accessibilityElement(children: .combine)
        }
    }
    private var personalize: some View {
        VStack(alignment: .leading, spacing: 23) {
            Text("Your pace.\nYour practice.").font(.system(.largeTitle, design: .rounded).weight(.bold))
            Text("Where are you starting?").font(.subheadline).foregroundStyle(StudioTheme.muted)
            VStack(spacing: 10) {
                ForEach(Experience.allCases, id: \.self) { experience in
                    Button { model.snapshot.preferences.experience = experience } label: {
                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(experience.title).font(.headline)
                                Text(experience.subtitle).font(.subheadline).foregroundStyle(StudioTheme.muted)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: model.snapshot.preferences.experience == experience ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(model.snapshot.preferences.experience == experience ? StudioTheme.accent : StudioTheme.line).font(.title2)
                        }.padding(18).background(StudioTheme.surface, in: RoundedRectangle(cornerRadius: 20))
                            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(model.snapshot.preferences.experience == experience ? StudioTheme.accent : StudioTheme.line))
                    }.buttonStyle(.plain).accessibilityAddTraits(model.snapshot.preferences.experience == experience ? .isSelected : [])
                }
            }
            Text("A little time, every day.").font(.headline).padding(.top, 5)
            HStack(spacing: 10) {
                ForEach([3, 5, 10], id: \.self) { minutes in
                    Button { model.snapshot.preferences.dailyMinutes = minutes } label: {
                        VStack(spacing: 4) { Text("\(minutes)").font(.system(.title, design: .rounded).weight(.bold)); Text("min / day").font(.caption) }
                            .frame(maxWidth: .infinity).padding(.vertical, 17)
                            .background(model.snapshot.preferences.dailyMinutes == minutes ? StudioTheme.soft : StudioTheme.surface, in: RoundedRectangle(cornerRadius: 19))
                            .overlay(RoundedRectangle(cornerRadius: 19).strokeBorder(model.snapshot.preferences.dailyMinutes == minutes ? StudioTheme.accent : StudioTheme.line))
                    }.buttonStyle(.plain).accessibilityLabel("\(minutes) minutes per day").accessibilityAddTraits(model.snapshot.preferences.dailyMinutes == minutes ? .isSelected : [])
                }
            }
            Text("No streaks to lose. Just room to improve.").font(.footnote).foregroundStyle(StudioTheme.muted)
        }
    }
}
