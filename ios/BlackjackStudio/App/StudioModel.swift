import Foundation
import SwiftUI
import UIKit
import UserNotifications
import BlackjackCore
import TrainingCore
import StudioCore

@MainActor
final class StudioModel: ObservableObject {
    @Published var snapshot: StudioSnapshot { didSet { persist() } }
    @Published var selectedTab = 0
    @Published var activeDrill: DrillKind?
    @Published var showPaywall = false
    @Published var showSettings = false
    @Published var storageMessage: String?
    @Published var lastDecision: StrategyAdvice?
    @Published var lastDecisionCorrect = false
    private let persistence: StudioPersistence

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        var directory = support.appendingPathComponent("BlackjackStudio", isDirectory: true)
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            directory = support.appendingPathComponent("BlackjackStudioUITesting", isDirectory: true)
            if ProcessInfo.processInfo.arguments.contains("--reset-state") { try? FileManager.default.removeItem(at: directory) }
        }
        #endif
        let storage = StudioStorage(directory: directory)
        persistence = StudioPersistence(storage: storage)
        let result = storage.load()
        snapshot = result.snapshot
        if result.recovered { storageMessage = "Your last saved session couldn’t be read. A safe copy was restored where available." }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--skip-onboarding") { snapshot.preferences.hasOnboarded = true }
        #endif
    }

    private func persist() {
        persistence.save(snapshot) { [weak self] result in
            if case .failure = result {
                Task { @MainActor in self?.storageMessage = "Progress couldn’t be saved on this device. Your current session is still available." }
            }
        }
    }
    func flushProgress() async { await persistence.flush() }
    func open(_ kind: DrillKind, hasPro: Bool) {
        if kind.isPremium && !hasPro { showPaywall = true }
        else { activeDrill = kind }
    }
    func finish(_ summary: DrillSummary) {
        snapshot.record(summary)
        StudioHaptics.success(enabled: snapshot.preferences.haptics)
    }
    func completeLesson(_ id: String) {
        snapshot.completedLessons.insert(id)
        StudioHaptics.success(enabled: snapshot.preferences.haptics)
    }
    func play(_ action: GameAction) {
        if let move = action.move, let advice = BasicStrategy.recommend(in: snapshot.game), GameEngine.availableMoves(in: snapshot.game).contains(move) {
            lastDecision = advice
            lastDecisionCorrect = advice.move == move
        } else if action.move == nil { lastDecision = nil }
        snapshot.play(action)
        StudioHaptics.tap(enabled: snapshot.preferences.haptics)
    }
    func completeOnboarding() {
        snapshot.preferences.hasOnboarded = true
        selectedTab = 0
    }
    func deletePracticeData() {
        var fresh = StudioSnapshot()
        fresh.preferences.hasOnboarded = true
        snapshot = fresh
        lastDecision = nil
        persistence.reset(to: fresh) { [weak self] result in
            if case .failure = result {
                Task { @MainActor in self?.storageMessage = "Practice data couldn’t be deleted. Please try again." }
            }
        }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["studio.daily-practice"])
        try? FileManager.default.removeItem(at: FileManager.default.temporaryDirectory.appendingPathComponent("StudioExport", isDirectory: true))
    }
    func exportPractice() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("StudioExport", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent("blackjack-studio-progress.json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(snapshot).write(to: destination, options: .atomic)
        return destination
    }
    func setReminder(_ enabled: Bool) async -> Bool {
        let center = UNUserNotificationCenter.current()
        if !enabled {
            center.removePendingNotificationRequests(withIdentifiers: ["studio.daily-practice"])
            snapshot.preferences.reminderEnabled = false
            return true
        }
        do {
            let permitted = try await center.requestAuthorization(options: [.alert, .sound])
            guard permitted else { return false }
            let content = UNMutableNotificationContent()
            content.title = "A little practice?"
            content.body = "Your next session is ready when you are."
            content.sound = .default
            var time = DateComponents()
            time.hour = snapshot.preferences.reminderHour
            time.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: time, repeats: true)
            try await center.add(UNNotificationRequest(identifier: "studio.daily-practice", content: content, trigger: trigger))
            snapshot.preferences.reminderEnabled = true
            return true
        } catch { return false }
    }
}
