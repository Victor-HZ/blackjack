import SwiftUI
import Charts
import TrainingCore

struct ProgressScreen: View {
    @EnvironmentObject private var model: StudioModel
    @EnvironmentObject private var purchases: PurchaseStore
    @Environment(\.dynamicTypeSize) private var typeSize
    private var sessions: [DrillSummary] { model.snapshot.sessions }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 9) {
                    Eyebrow(text: "EVERY SESSION COUNTS")
                    Text("See yourself improve.").font(.system(.largeTitle, design: .rounded).weight(.bold)).foregroundStyle(StudioTheme.ink)
                }
                let metricsLayout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
                metricsLayout {
                    metric(value: model.snapshot.trainingAccuracy.map { "\(Int(($0 * 100).rounded()))%" } ?? "—", label: "Accuracy", symbol: "scope")
                    metric(value: "\(sessions.count)", label: "Sessions", symbol: "rectangle.stack").accessibilityElement(children: .combine).accessibilityIdentifier("progress.sessions")
                }
                StudioCard {
                    VStack(alignment: .leading, spacing: 21) {
                        SectionTitle(title: "A week of practice")
                        HStack {
                            ForEach(Array(model.snapshot.activeDays(ending: Date()).enumerated()), id: \.offset) { offset, active in
                                let day = Calendar.current.date(byAdding: .day, value: offset - 6, to: Date()) ?? Date()
                                VStack(spacing: 9) {
                                    ZStack {
                                        Circle().fill(active ? StudioTheme.accent : StudioTheme.soft)
                                        Image(systemName: active ? "checkmark" : "minus").font(.caption.weight(.bold)).foregroundStyle(active ? StudioTheme.surface : StudioTheme.muted)
                                    }.frame(width: 31, height: 31)
                                    Text(day.formatted(.dateTime.weekday(.narrow))).font(.caption2).foregroundStyle(StudioTheme.muted)
                                }.frame(maxWidth: .infinity)
                                    .accessibilityElement(children: .ignore)
                                    .accessibilityLabel("\(day.formatted(.dateTime.weekday(.wide))), \(active ? "practiced" : "rest day")")
                            }
                        }
                        Text("Rest days are part of the rhythm.").font(.footnote).foregroundStyle(StudioTheme.muted)
                    }
                }
                StudioCard {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionTitle(title: "Accuracy over time", caption: "Last 20 sessions")
                        if sessions.count >= 2 {
                            Chart(Array(sessions.suffix(20))) { session in
                                LineMark(x: .value("Session", session.date), y: .value("Accuracy", session.accuracyPercent))
                                    .foregroundStyle(StudioTheme.accent).interpolationMethod(.linear)
                                PointMark(x: .value("Session", session.date), y: .value("Accuracy", session.accuracyPercent))
                                    .foregroundStyle(StudioTheme.accent)
                                    .accessibilityLabel(session.kind.title)
                                    .accessibilityValue("\(session.accuracyPercent) percent, \(session.date.formatted(date: .abbreviated, time: .shortened))")
                            }.chartYScale(domain: 0...100).chartXAxis(.hidden).frame(height: 170)
                            Text("Aim for accuracy before speed.").font(.footnote).foregroundStyle(StudioTheme.muted)
                        } else {
                            EmptyState(symbol: "chart.xyaxis.line", title: "Your practice has a story.", message: "Complete two sessions to see your trend.")
                        }
                    }
                }
                SectionTitle(title: "Your skills")
                StudioCard {
                    VStack(spacing: 19) {
                        ForEach(DrillKind.allCases) { kind in
                            let history = Array(sessions.filter { $0.kind == kind }.suffix(5))
                            let total = history.reduce(0) { $0 + $1.total }
                            let correct = history.reduce(0) { $0 + $1.correct }
                            Button { model.open(kind, hasPro: purchases.hasPro) } label: {
                                HStack(spacing: 13) {
                                    Image(systemName: kind.symbol).frame(width: 25).foregroundStyle(StudioTheme.accent)
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(kind.title).font(.subheadline.weight(.medium)).foregroundStyle(StudioTheme.ink)
                                        ProgressView(value: total == 0 ? 0 : Double(correct) / Double(total)).tint(StudioTheme.accent)
                                    }
                                    Text(total == 0 ? "—" : "\(Int((Double(correct) / Double(total) * 100).rounded()))%")
                                        .font(.subheadline.monospacedDigit()).foregroundStyle(StudioTheme.muted).frame(minWidth: 42)
                                    Image(systemName: "chevron.right").font(.caption2).foregroundStyle(StudioTheme.muted)
                                }.frame(minHeight: 44)
                            }.buttonStyle(.plain)
                        }
                        Text("Based on your last five sessions per skill.").font(.caption).foregroundStyle(StudioTheme.muted)
                    }
                }
                SectionTitle(title: "Recent sessions")
                if sessions.isEmpty {
                    EmptyState(symbol: "leaf", title: "Start with one session.", message: "Your results and review notes will live here.")
                    Button { model.selectedTab = 0 } label: { Text("Find a drill") }.buttonStyle(StudioPrimaryButton())
                } else {
                    VStack(spacing: 11) {
                        ForEach(sessions.suffix(10).reversed()) { session in
                            NavigationLink { SessionReviewScreen(summary: session) } label: {
                                HStack(spacing: 13) {
                                    Image(systemName: session.kind.symbol).font(.title3).frame(width: 43, height: 43).foregroundStyle(StudioTheme.accent).background(StudioTheme.soft, in: RoundedRectangle(cornerRadius: 14))
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(session.kind.title).font(.headline).foregroundStyle(StudioTheme.ink)
                                        Text(session.date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(StudioTheme.muted)
                                    }
                                    Spacer(minLength: 0)
                                    Text("\(session.accuracyPercent)%").font(.system(.title3, design: .rounded).weight(.bold)).foregroundStyle(StudioTheme.accent)
                                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(StudioTheme.muted)
                                }.padding(16).background(StudioTheme.surface, in: RoundedRectangle(cornerRadius: 21))
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }.padding(22).frame(maxWidth: 850).frame(maxWidth: .infinity)
        }.background(StudioTheme.background).navigationTitle("Progress").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { model.showSettings = true } label: { Image(systemName: "slider.horizontal.3") }.accessibilityLabel("Settings") } }
    }
    private func metric(value: String, label: String, symbol: String) -> some View {
        StudioCard {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: symbol).font(.title3).foregroundStyle(StudioTheme.accent)
                Text(value).font(.system(.largeTitle, design: .rounded).weight(.bold)).foregroundStyle(StudioTheme.ink)
                Text(label).font(.subheadline).foregroundStyle(StudioTheme.muted)
            }
        }
    }
}

struct SessionReviewScreen: View {
    var summary: DrillSummary
    @EnvironmentObject private var model: StudioModel
    @EnvironmentObject private var purchases: PurchaseStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("\(summary.accuracyPercent)%").font(.system(size: 64, weight: .bold, design: .rounded)).minimumScaleFactor(0.6).foregroundStyle(StudioTheme.accent)
                Text("\(summary.correct) of \(summary.total) correct").font(.title3.weight(.semibold)).foregroundStyle(StudioTheme.ink)
                Text(summary.nextSuggestion).font(.subheadline).foregroundStyle(StudioTheme.muted)
                if summary.mistakes.isEmpty {
                    StudioCard { Label("No missed counts. Nicely done.", systemImage: "checkmark.seal").foregroundStyle(StudioTheme.accent) }
                } else {
                    SectionTitle(title: "Worth another look")
                    ForEach(summary.mistakes) { response in
                        StudioCard {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Your answer: \(DrillPrompt.format(response.answer, signed: summary.kind != .deckEstimation))").foregroundStyle(StudioTheme.muted)
                                    Spacer()
                                    Text(response.prompt.formattedAnswer).fontWeight(.bold).foregroundStyle(StudioTheme.accent)
                                }.font(.subheadline)
                                Text(response.prompt.explanation).font(.subheadline).foregroundStyle(StudioTheme.ink)
                            }
                        }
                    }
                }
                Button { model.open(summary.kind, hasPro: purchases.hasPro) } label: { Text("Practice again") }.buttonStyle(StudioPrimaryButton())
            }.padding(24).frame(maxWidth: 700).frame(maxWidth: .infinity)
        }.background(StudioTheme.background).navigationTitle(summary.kind.title).navigationBarTitleDisplayMode(.inline)
    }
}
