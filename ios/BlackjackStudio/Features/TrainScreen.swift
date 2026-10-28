import SwiftUI
import TrainingCore
import BlackjackCore

struct TrainScreen: View {
    @EnvironmentObject private var model: StudioModel
    @EnvironmentObject private var purchases: PurchaseStore
    @Environment(\.dynamicTypeSize) private var textSize
    private var nextDrill: DrillKind {
        if model.snapshot.sessions.isEmpty && model.snapshot.preferences.experience != .starting { return .runningCount }
        return TrainingRecommendation.next(history: model.snapshot.sessions, hasPro: purchases.hasPro)
    }
    private var todaySeconds: Double { model.snapshot.practiceSeconds(on: Date()) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(text: "BLACKJACK STUDIO")
                        Text("Make it\nsecond nature.").font(.system(.largeTitle, design: .rounded).weight(.bold)).foregroundStyle(StudioTheme.ink)
                    }
                    Spacer()
                    Button { model.showSettings = true } label: {
                        Image(systemName: "slider.horizontal.3").font(.title3).frame(width: 46, height: 46).background(StudioTheme.surface, in: Circle())
                            .overlay(Circle().strokeBorder(StudioTheme.line))
                    }.buttonStyle(.plain).accessibilityLabel("Settings")
                }
                nextSession
                dailyPractice
                SectionTitle(title: "Find your focus", caption: "Short sessions. Lasting skill.")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: textSize.isAccessibilitySize ? 1 : 2), spacing: 12) {
                    ForEach(DrillKind.allCases) { kind in
                        Button { model.open(kind, hasPro: purchases.hasPro) } label: { drillTile(kind) }
                            .buttonStyle(.plain).disabled(kind.isPremium && !purchases.hasLoadedEntitlements).accessibilityIdentifier("drill-\(kind.rawValue)")
                    }
                }
                if !purchases.hasPro {
                    Button { model.showPaywall = true } label: {
                        HStack(spacing: 15) {
                            Image(systemName: "sparkles").font(.title2).foregroundStyle(StudioTheme.accent)
                            VStack(alignment: .leading, spacing: 5) {
                                Text("A deeper practice.").font(.headline)
                                Text("Every drill. One lifetime unlock.").font(.subheadline).foregroundStyle(StudioTheme.muted)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "arrow.up.right")
                        }.padding(21).background(StudioTheme.soft, in: RoundedRectangle(cornerRadius: 23))
                    }.buttonStyle(.plain).accessibilityLabel("Explore Pro. Every drill, one lifetime unlock.")
                }
                HStack { Image(systemName: "lock.shield"); Text("Your progress stays on your device.") }
                    .font(.footnote).foregroundStyle(StudioTheme.muted).frame(maxWidth: .infinity).padding(.bottom, 8)
            }.padding(22).frame(maxWidth: 850).frame(maxWidth: .infinity)
        }.background(StudioTheme.background).toolbar(.hidden, for: .navigationBar)
    }
    private var nextSession: some View {
        VStack(alignment: .leading, spacing: 23) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 13) {
                    Text("YOUR NEXT SESSION").font(.system(.caption2, design: .rounded).weight(.bold)).tracking(2).foregroundStyle(StudioTheme.lime.opacity(0.85))
                    Text(nextDrill.title).font(.system(.title, design: .rounded).weight(.bold)).foregroundStyle(.white)
                    Text(nextDrill.subtitle).font(.subheadline).foregroundStyle(.white.opacity(0.8)).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 3)
                if !textSize.isAccessibilitySize {
                    NativePlayingCard(card: Card(rank: .five, suit: .spades), width: 55).rotationEffect(.degrees(10)).padding(.top, 12).accessibilityHidden(true)
                }
            }
            HStack {
                Label(nextDrill.durationLabel, systemImage: "clock")
                Spacer()
                Text(model.snapshot.sessions.isEmpty ? "A good place to begin" : "Picked for your progress")
            }.font(.caption).foregroundStyle(.white.opacity(0.75))
            Button { model.open(nextDrill, hasPro: purchases.hasPro) } label: {
                HStack { Text("Start session"); Spacer(); Image(systemName: "arrow.right") }.padding(.horizontal, 20)
            }.buttonStyle(StudioPrimaryButton(light: true)).accessibilityIdentifier("startSession")
        }.padding(25).background(StudioTheme.forest.gradient, in: RoundedRectangle(cornerRadius: 30))
    }
    private var dailyPractice: some View {
        HStack(spacing: 17) {
            ZStack {
                ProgressRing(progress: todaySeconds / Double(model.snapshot.preferences.dailyMinutes * 60))
                Image(systemName: todaySeconds >= Double(model.snapshot.preferences.dailyMinutes * 60) ? "checkmark" : "leaf").font(.title3).foregroundStyle(StudioTheme.accent)
            }.frame(width: 46, height: 46)
            VStack(alignment: .leading, spacing: 4) {
                Text(todaySeconds >= Double(model.snapshot.preferences.dailyMinutes * 60) ? "A little better today." : "Your daily moment.").font(.headline).foregroundStyle(StudioTheme.ink)
                Text("\(Int(todaySeconds / 60)) of \(model.snapshot.preferences.dailyMinutes) minutes practiced").font(.caption).foregroundStyle(StudioTheme.muted)
            }
            Spacer(minLength: 0)
            Text("\(model.snapshot.sessions.count)").font(.system(.title2, design: .rounded).weight(.bold)).foregroundStyle(StudioTheme.ink)
                .accessibilityLabel("\(model.snapshot.sessions.count) completed sessions")
        }.padding(20).background(StudioTheme.surface, in: RoundedRectangle(cornerRadius: 23))
            .overlay(RoundedRectangle(cornerRadius: 23).strokeBorder(StudioTheme.line))
    }
    private func drillTile(_ kind: DrillKind) -> some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack {
                Image(systemName: kind.symbol).font(.system(size: 21, weight: .medium)).foregroundStyle(StudioTheme.accent)
                    .frame(width: 45, height: 45).background(StudioTheme.soft, in: RoundedRectangle(cornerRadius: 14))
                Spacer()
                if kind.isPremium && !purchases.hasPro { Image(systemName: "lock").font(.caption).foregroundStyle(StudioTheme.muted) }
                else { Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(StudioTheme.muted) }
            }
            VStack(alignment: .leading, spacing: 7) {
                Text(kind.title).font(.system(.headline, design: .rounded)).foregroundStyle(StudioTheme.ink).fixedSize(horizontal: false, vertical: true)
                Text(kind.durationLabel).font(.caption).foregroundStyle(StudioTheme.muted)
            }
        }.padding(18).frame(maxWidth: .infinity, minHeight: 148, alignment: .topLeading)
            .background(StudioTheme.surface, in: RoundedRectangle(cornerRadius: 23))
            .overlay(RoundedRectangle(cornerRadius: 23).strokeBorder(StudioTheme.line))
            .accessibilityElement(children: .combine)
            .accessibilityHint(kind.isPremium && !purchases.hasPro ? "Requires a one-time Pro unlock" : "Start this practice drill")
    }
}
