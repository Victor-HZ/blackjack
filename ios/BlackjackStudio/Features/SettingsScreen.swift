import SwiftUI
import UIKit
import StoreKit
import StudioCore

struct SettingsScreen: View {
    @EnvironmentObject private var model: StudioModel
    @EnvironmentObject private var purchases: PurchaseStore
    @Environment(\.dismiss) private var dismiss
    @State private var showUpgrade = false
    @State private var legalDocument: CommerceLegalDocument?
    @State private var confirmDelete = false
    @State private var reminderBusy = false
    @State private var reminderDenied = false
    @State private var exportURL: URL?
    @State private var exportError = false
    @State private var showTrainingNote = false
    @State private var restoreFeedback: String?
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        Image(systemName: "suit.spade.fill").font(.title2).frame(width: 40, height: 40).foregroundStyle(StudioTheme.accent)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Blackjack Studio").font(.headline)
                            Text(purchases.hasPro ? "Pro unlocked" : "Free edition").font(.subheadline).foregroundStyle(StudioTheme.muted)
                        }
                    }.padding(.vertical, 6)
                    if !purchases.hasPro { Button { showUpgrade = true } label: { Label("Blackjack Studio Pro", systemImage: "lock.open") } }
                    Button { Task { await purchases.restore(); restoreFeedback = purchases.statusMessage ?? purchases.errorMessage } } label: {
                        HStack { Text("Restore purchases"); Spacer(); if purchases.isRestoring { ProgressView() } }
                    }.disabled(purchases.isRestoring || purchases.isPurchasing)
                }
                Section("Practice") {
                    Picker("Daily goal", selection: $model.snapshot.preferences.dailyMinutes) {
                        ForEach([3, 5, 10], id: \.self) { Text("\($0) minutes").tag($0) }
                    }
                    Toggle("Haptics", isOn: $model.snapshot.preferences.haptics)
                    Toggle("Daily reminder", isOn: Binding(get: { model.snapshot.preferences.reminderEnabled }, set: { enabled in
                        reminderBusy = true
                        Task { let success = await model.setReminder(enabled); reminderBusy = false; if !success { reminderDenied = true } }
                    })).disabled(reminderBusy)
                    if model.snapshot.preferences.reminderEnabled {
                        Picker("Reminder time", selection: $model.snapshot.preferences.reminderHour) {
                            ForEach(0..<24, id: \.self) { hour in Text(timeLabel(hour)).tag(hour) }
                        }.onChange(of: model.snapshot.preferences.reminderHour) { _, _ in Task { _ = await model.setReminder(true) } }
                    }
                }
                Section {
                    Button { do { exportURL = try model.exportPractice() } catch { exportError = true } } label: { Label("Export progress", systemImage: "square.and.arrow.up") }
                    if let exportURL { ShareLink(item: exportURL) { Label("Share progress file", systemImage: "arrow.up.doc") } }
                    Button(role: .destructive) { confirmDelete = true } label: { Label("Delete practice data", systemImage: "trash") }
                } header: { Text("Your data") } footer: { Text("Stored on this device. Deleting practice data does not remove your Pro purchase.") }
                Section("About") {
                    Button { showTrainingNote = true } label: { Label("Practice responsibly", systemImage: "hand.raised") }
                    Button { legalDocument = .privacy } label: { Label("Privacy", systemImage: "lock.shield") }
                    Button { legalDocument = .terms } label: { Label("Terms of use", systemImage: "doc.text") }
                    if let url = configuredURL("SupportURL") { Link(destination: url) { Label("Support", systemImage: "questionmark.circle") } }
                    HStack { Text("Version"); Spacer(); Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0").foregroundStyle(StudioTheme.muted) }
                }
            }.scrollContentBackground(.hidden).background(StudioTheme.background).foregroundStyle(StudioTheme.ink)
                .navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .sheet(isPresented: $showUpgrade) { PaywallView() }
                .sheet(item: $legalDocument) { CommerceLegalView(document: $0) }
                .sheet(isPresented: $showTrainingNote) { trainingNote }
                .confirmationDialog("Delete your practice data?", isPresented: $confirmDelete, titleVisibility: .visible) {
                    Button("Delete practice data", role: .destructive) { model.deletePracticeData(); exportURL = nil }
                    Button("Cancel", role: .cancel) {}
                } message: { Text("This clears lessons, sessions, preferences, and the practice table on this device. Your Pro unlock stays yours.") }
                .alert("Reminders are off", isPresented: $reminderDenied) {
                    Button("Open Settings") { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }
                    Button("Not now", role: .cancel) {}
                } message: { Text("You can allow reminders in iOS Settings whenever you want.") }
                .alert("Export unavailable", isPresented: $exportError) { Button("OK", role: .cancel) {} } message: { Text("Your progress couldn’t be exported. Please try again.") }
                .alert("Purchases", isPresented: Binding(get: { restoreFeedback != nil }, set: { if !$0 { restoreFeedback = nil; purchases.clearMessage() } })) {
                    Button("OK") { restoreFeedback = nil; purchases.clearMessage() }
                } message: { Text(restoreFeedback ?? "") }
        }
    }
    private func timeLabel(_ hour: Int) -> String {
        let date = Calendar.current.date(from: DateComponents(hour: hour)) ?? Date()
        return date.formatted(.dateTime.hour().minute())
    }
    private func configuredURL(_ key: String) -> URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String, let url = URL(string: raw), url.scheme == "https", url.host != nil else { return nil }
        return url
    }
    private var trainingNote: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Practice only").font(.title2.weight(.semibold))
                    Text("All cards here are simulated. This app teaches mental arithmetic and decision-making, not live gambling assistance.").font(.body).foregroundStyle(StudioTheme.muted)
                    StudioCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Label("Never use the app while gambling.", systemImage: "iphone.slash")
                            Label("Laws and venue rules vary.", systemImage: "globe")
                            Label("Counting does not guarantee a win.", systemImage: "chart.line.downtrend.xyaxis")
                        }.font(.subheadline).foregroundStyle(StudioTheme.ink)
                    }
                    Text("Mental counting and using an electronic device are different activities. Some jurisdictions prohibit devices that track cards, analyze play, or assist wagering. Casinos may restrict or refuse play even where mental counting is not prohibited.").font(.footnote).foregroundStyle(StudioTheme.muted)
                    Text("No real-money play, deposits, payouts, or casino connections are provided.").font(.footnote).foregroundStyle(StudioTheme.muted)
                }.padding(26).frame(maxWidth: 650).frame(maxWidth: .infinity)
            }.background(StudioTheme.background).foregroundStyle(StudioTheme.ink).navigationTitle("Practice responsibly").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showTrainingNote = false } } }
        }
    }
}
