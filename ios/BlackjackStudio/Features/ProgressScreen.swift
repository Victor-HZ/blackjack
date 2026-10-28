import SwiftUI
import Charts
import TrainingCore

struct ProgressScreen: View {
    @EnvironmentObject private var model: StudioModel
    @EnvironmentObject private var purchases: PurchaseStore
    @Environment(\.dynamicTypeSize) private var typeSize
    private var sessions: [DrillSummary] { model.snapshot.sessions }
    private var recent: [DrillSummary] { Array(sessions.suffix(10).reversed()) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                StudioCard {
                    let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 20)) : AnyLayout(HStackLayout(spacing: 20))
                    layout {
                        metric(value: model.snapshot.trainingAccuracy.map { "\(Int(($0 * 100).rounded()))%" } ?? "—", label: "Accuracy")
                        if !typeSize.isAccessibilitySize { Divider() }
                        metric(value: "\(sessions.count)", label: "Sessions")
                            .accessibilityElement(children: .combine).accessibilityIdentifier("progress.sessions")
                    }.fixedSize(horizontal: false, vertical: true)
                }
                week
                StudioCard {
                    VStack(alignment: .leading, spacing: 18) {
                        SectionTitle(title: "Accuracy", caption: "Last 20 sessions")
                        if sessions.count >= 2 {
                            Chart(Array(sessions.suffix(20))) { session in
                                LineMark(x: .value("Session", session.date), y: .value("Accuracy", session.accuracyPercent))
                                    .foregroundStyle(StudioTheme.accent).interpolationMethod(.linear)
                                PointMark(x: .value("Session", session.date), y: .value("Accuracy", session.accuracyPercent))
                                    .foregroundStyle(StudioTheme.accent)
                                    .accessibilityLabel(session.kind.title)
                                    .accessibilityValue("\(session.accuracyPercent) percent, \(session.date.formatted(date: .abbreviated, time: .shortened))")
                            }.chartYScale(domain: 0...100).chartXAxis(.hidden).frame(height: 170)
                        } else {
                            EmptyState(symbol: "chart.xyaxis.line", title: "No trend yet", message: "Complete two sessions to see your accuracy over time.")
                        }
                    }
                }
                skills
                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle(title: "Recent sessions")
                    if sessions.isEmpty {
                        EmptyState(symbol: "clock", title: "No sessions yet", message: "Completed drills appear here.")
                        Button { model.selectedTab = 0 } label: { Text("Choose a drill") }.buttonStyle(StudioPrimaryButton())
                    } else {
                        VStack(spacing: 0) {
                            ForEach(recent) { session in
                                NavigationLink { SessionReviewScreen(summary: session) } label: { sessionRow(session) }.buttonStyle(.plain)
                                if session.id != recent.last?.id { Divider().padding(.leading, 18) }
                            }
                        }.background(StudioTheme.surface, in: RoundedRectangle(cornerRadius: StudioTheme.radius))
                    }
                }
            }.padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 30).frame(maxWidth: 760).frame(maxWidth: .infinity)
        }.background(StudioTheme.background).navigationTitle("Progress").navigationBarTitleDisplayMode(.large)
            .toolbar { ToolbarItem(placement: .topBarTrailing) {
                Button { model.showSettings = true } label: { Image(systemName: "slider.horizontal.3").frame(width: 44, height: 44) }.accessibilityLabel("Settings")
            } }
    }
    private var week: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(title: "This week")
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(model.snapshot.activeDays(ending: Date()).enumerated()), id: \.offset) { offset, active in
                        let day = Calendar.current.date(byAdding: .day, value: offset - 6, to: Date()) ?? Date()
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: active ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 22)).foregroundStyle(active ? StudioTheme.accent : StudioTheme.muted)
                                .padding(.top, 5).accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(day.formatted(.dateTime.weekday(.wide))).font(.body).foregroundStyle(StudioTheme.ink)
                                Text(active ? "Practiced" : "No practice").font(.subheadline).foregroundStyle(StudioTheme.muted)
                            }
                        }.accessibilityElement(children: .combine)
                    }
                }
            } else {
                HStack {
                    ForEach(Array(model.snapshot.activeDays(ending: Date()).enumerated()), id: \.offset) { offset, active in
                        let day = Calendar.current.date(byAdding: .day, value: offset - 6, to: Date()) ?? Date()
                        VStack(spacing: 9) {
                            ZStack {
                                Circle().fill(active ? StudioTheme.accent : StudioTheme.surface)
                                Image(systemName: active ? "checkmark" : "minus").font(.caption.weight(.semibold))
                                    .foregroundStyle(active ? StudioTheme.background : StudioTheme.muted)
                            }.frame(width: 30, height: 30)
                            Text(day.formatted(.dateTime.weekday(.narrow))).font(.caption2).foregroundStyle(StudioTheme.muted)
                        }.frame(maxWidth: .infinity)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(day.formatted(.dateTime.weekday(.wide))), \(active ? "practiced" : "no practice")")
                    }
                }
            }
        }
    }
    private var skills: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Skills")
            VStack(spacing: 0) {
                ForEach(DrillKind.allCases) { kind in
                    let history = Array(sessions.filter { $0.kind == kind }.suffix(5))
                    let total = history.reduce(0) { $0 + $1.total }
                    let correct = history.reduce(0) { $0 + $1.correct }
                    Button { model.open(kind, hasPro: purchases.hasPro) } label: {
                        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10)) : AnyLayout(HStackLayout(spacing: 13))
                        layout {
                            VStack(alignment: .leading, spacing: 9) {
                                Text(kind.title).font(.body).foregroundStyle(StudioTheme.ink)
                                ProgressView(value: total == 0 ? 0 : Double(correct) / Double(total)).tint(StudioTheme.accent)
                            }
                            HStack(spacing: 13) {
                                Text(total == 0 ? "—" : "\(Int((Double(correct) / Double(total) * 100).rounded()))%")
                                    .font(.subheadline.monospacedDigit()).foregroundStyle(StudioTheme.muted).frame(minWidth: 42, alignment: .leading)
                                if typeSize.isAccessibilitySize { Spacer() }
                                Image(systemName: "chevron.right").font(.caption2.weight(.semibold)).foregroundStyle(StudioTheme.muted)
                            }
                        }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).padding(.horizontal, 18).padding(.vertical, 13)
                    }.buttonStyle(.plain)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(kind.title)
                        .accessibilityValue(total == 0 ? "No sessions" : "\(Int((Double(correct) / Double(total) * 100).rounded())) percent accuracy")
                        .accessibilityHint("Opens this drill")
                    if kind != DrillKind.allCases.last { Divider().padding(.leading, 18) }
                }
            }.background(StudioTheme.surface, in: RoundedRectangle(cornerRadius: StudioTheme.radius))
            Text("Last five sessions per skill.").font(.caption).foregroundStyle(StudioTheme.muted)
        }
    }
    private func sessionRow(_ session: DrillSummary) -> some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10)) : AnyLayout(HStackLayout(spacing: 14))
        return layout {
            VStack(alignment: .leading, spacing: 5) {
                Text(session.kind.title).font(.body).foregroundStyle(StudioTheme.ink)
                Text(session.date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(StudioTheme.muted)
            }
            if !typeSize.isAccessibilitySize { Spacer(minLength: 0) }
            HStack(spacing: 12) {
                Text("\(session.accuracyPercent)%").font(.body.weight(.medium).monospacedDigit()).foregroundStyle(StudioTheme.ink)
                Image(systemName: "chevron.right").font(.caption2.weight(.semibold)).foregroundStyle(StudioTheme.muted)
            }
        }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).padding(.horizontal, 18).padding(.vertical, 12)
    }
    private func metric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value).font(.largeTitle.weight(.semibold).monospacedDigit()).foregroundStyle(StudioTheme.ink)
            Text(label).font(.subheadline).foregroundStyle(StudioTheme.muted)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SessionReviewScreen: View {
    var summary: DrillSummary
    @EnvironmentObject private var model: StudioModel
    @EnvironmentObject private var purchases: PurchaseStore
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(summary.accuracyPercent)%").font(.largeTitle.weight(.semibold).monospacedDigit()).foregroundStyle(StudioTheme.ink)
                    Text("\(summary.correct) of \(summary.total) correct").font(.subheadline).foregroundStyle(StudioTheme.muted)
                }
                Text(summary.nextSuggestion).font(.subheadline).foregroundStyle(StudioTheme.muted)
                if summary.mistakes.isEmpty {
                    Label("All answers correct", systemImage: "checkmark.circle").font(.body).foregroundStyle(StudioTheme.accent)
                } else {
                    SectionTitle(title: "Mistakes")
                    ForEach(summary.mistakes) { response in
                        StudioCard {
                            VStack(alignment: .leading, spacing: 12) {
                                let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout())
                                layout {
                                    Text("Your answer: \(DrillPrompt.format(response.answer, signed: summary.kind != .deckEstimation))").foregroundStyle(StudioTheme.muted)
                                    if !typeSize.isAccessibilitySize { Spacer() }
                                    Text("Correct: \(response.prompt.formattedAnswer)").fontWeight(.semibold).foregroundStyle(StudioTheme.accent)
                                }.font(.subheadline)
                                Text(response.prompt.explanation).font(.subheadline).foregroundStyle(StudioTheme.ink)
                            }
                        }
                    }
                }
                Button { model.open(summary.kind, hasPro: purchases.hasPro) } label: { Text("Practice again") }.buttonStyle(StudioPrimaryButton())
            }.padding(20).frame(maxWidth: 700).frame(maxWidth: .infinity)
        }.background(StudioTheme.background).navigationTitle(summary.kind.title).navigationBarTitleDisplayMode(.inline)
    }
}
