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
            VStack(alignment: .leading, spacing: 26) {
                dailyPractice
                nextSession
                simulationEntry
                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle(title: "Drills")
                    VStack(spacing: 0) {
                        ForEach(Array(DrillKind.allCases.enumerated()), id: \.element.id) { index, kind in
                            if index > 0 { Divider().overlay(StudioTheme.line).padding(.leading, 58) }
                            Button { model.open(kind, hasPro: purchases.hasPro) } label: { drillRow(kind) }
                                .buttonStyle(.plain)
                                .disabled(kind.isPremium && !purchases.hasLoadedEntitlements)
                                .accessibilityIdentifier("drill-\(kind.rawValue)")
                        }
                    }.background(StudioTheme.surface, in: RoundedRectangle(cornerRadius: StudioTheme.radius))
                        .clipShape(RoundedRectangle(cornerRadius: StudioTheme.radius))
                }
                if !purchases.hasPro {
                    Button { model.showPaywall = true } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Studio Pro").font(.subheadline.weight(.semibold)).foregroundStyle(StudioTheme.ink)
                                Text("All drills and table rules. One purchase.").font(.footnote).foregroundStyle(StudioTheme.muted)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(StudioTheme.muted)
                        }.frame(minHeight: 44).contentShape(Rectangle())
                    }.buttonStyle(.plain).padding(.horizontal, 4).accessibilityLabel("Studio Pro. All drills and table rules. One purchase.")
                }
            }.padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 30)
                .frame(maxWidth: 760).frame(maxWidth: .infinity)
        }.background(StudioTheme.background)
            .navigationTitle("Practice").navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { model.showSettings = true } label: { Image(systemName: "slider.horizontal.3").frame(minWidth: 44, minHeight: 44) }
                        .accessibilityLabel("Settings")
                }
            }
    }
    private var simulationEntry: some View {
        Button { model.showSimulation = true } label: {
            HStack(spacing: 14) {
                Image(systemName: "suit.spade").font(.title3).foregroundStyle(StudioTheme.accent)
                VStack(alignment: .leading, spacing: 5) {
                    Text(model.snapshot.activeSimulation == nil ? "Simulation" : model.snapshot.activeSimulation?.stage == .complete ? "Simulation results" : "Resume simulation")
                        .font(.headline).foregroundStyle(StudioTheme.ink)
                    Text(model.snapshot.activeSimulation.map { "\($0.completedRounds) of \($0.configuration.rounds) rounds completed" } ?? "10, 25, or 50 rounds. Feedback on your play.")
                        .font(.subheadline).foregroundStyle(StudioTheme.muted)
                }.multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(StudioTheme.muted)
            }.padding(18).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .background(StudioTheme.surface, in: RoundedRectangle(cornerRadius: StudioTheme.radius))
                .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityIdentifier("simulation.open")
    }
    private var nextSession: some View {
        StudioCard {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(model.snapshot.sessions.isEmpty ? "Start here" : "Recommended").font(.footnote).foregroundStyle(StudioTheme.muted)
                        Text(nextDrill.title).font(.title2.weight(.semibold)).foregroundStyle(StudioTheme.ink)
                        Text(description(nextDrill)).font(.subheadline).foregroundStyle(StudioTheme.muted).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    if !textSize.isAccessibilitySize {
                        NativePlayingCard(card: Card(rank: .five, suit: .spades), width: 42)
                            .padding(.top, 3).accessibilityHidden(true)
                    }
                }
                Button { model.open(nextDrill, hasPro: purchases.hasPro) } label: {
                    HStack(spacing: 10) {
                        Text("Start session")
                        if !textSize.isAccessibilitySize {
                            Text("·").accessibilityHidden(true)
                            Text(nextDrill.durationLabel).font(.subheadline.weight(.regular))
                        }
                    }
                }.buttonStyle(StudioPrimaryButton()).accessibilityLabel("Start session").accessibilityValue(nextDrill.durationLabel).accessibilityIdentifier("startSession")
            }
        }
    }
    private var dailyPractice: some View {
        HStack(spacing: 12) {
            ZStack {
                ProgressRing(progress: todaySeconds / Double(model.snapshot.preferences.dailyMinutes * 60))
                if todaySeconds >= Double(model.snapshot.preferences.dailyMinutes * 60) {
                    Image(systemName: "checkmark").font(.caption.weight(.semibold)).foregroundStyle(StudioTheme.accent)
                }
            }.frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text("Today").font(.subheadline.weight(.semibold)).foregroundStyle(StudioTheme.ink)
                Text("\(Int(todaySeconds / 60)) of \(model.snapshot.preferences.dailyMinutes) min").font(.footnote.monospacedDigit()).foregroundStyle(StudioTheme.muted)
            }
            Spacer()
            if !textSize.isAccessibilitySize {
                Text(Date(), format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                    .font(.footnote).foregroundStyle(StudioTheme.muted)
            }
        }.padding(.horizontal, 4).accessibilityElement(children: .combine)
    }
    private func drillRow(_ kind: DrillKind) -> some View {
        HStack(spacing: 14) {
            Image(systemName: kind.symbol).font(.system(size: 19, weight: .regular))
                .foregroundStyle(StudioTheme.accent).frame(width: 24).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(kind.title).font(.body.weight(.medium)).foregroundStyle(StudioTheme.ink)
                Text(kind.durationLabel).font(.footnote).foregroundStyle(StudioTheme.muted)
            }
            Spacer(minLength: 10)
            Image(systemName: kind.isPremium && !purchases.hasPro ? "lock" : "chevron.right")
                .font(.caption).foregroundStyle(StudioTheme.muted)
        }.frame(minHeight: 48).padding(.horizontal, 18).padding(.vertical, 13)
            .contentShape(Rectangle()).accessibilityElement(children: .combine)
            .accessibilityHint(kind.isPremium && !purchases.hasPro ? "Requires a one-time Pro unlock" : "Start this drill")
    }
    private func description(_ kind: DrillKind) -> String {
        switch kind {
        case .cardValues: return "Identify each Hi-Lo value."
        case .pairs: return "Add or cancel two cards at a time."
        case .runningCount: return "Keep a total as cards are dealt."
        case .fullDeck: return "Check your count through 52 cards."
        case .trueCount: return "Divide by the decks remaining."
        case .deckEstimation: return "Estimate the cards left in the shoe."
        }
    }
}
