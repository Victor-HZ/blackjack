import XCTest
import Foundation
import BlackjackCore
import TrainingCore
@testable import StudioCore

final class StudioCoreTests: XCTestCase {
    func testFreshSnapshotRoundTripsWithNoFabricatedProgress() throws {
        let state = StudioSnapshot()
        XCTAssertTrue(state.isValid)
        XCTAssertNil(state.accuracy)
        XCTAssertNil(state.trainingAccuracy)
        XCTAssertTrue(state.sessions.isEmpty)
        XCTAssertTrue(state.simulationSessions.isEmpty)
        XCTAssertNil(state.activeSimulation)
        XCTAssertNil(state.simulationStrategyAccuracy)
        XCTAssertNil(state.simulationCountAccuracy)
        let restored = try JSONDecoder().decode(StudioSnapshot.self, from: JSONEncoder().encode(state))
        XCTAssertTrue(restored.isValid)
        XCTAssertEqual(restored.game, state.game)
    }
    func testDuplicateFinishedSessionDoesNotDoubleCount() {
        var state = StudioSnapshot()
        let summary = DrillSummary(kind: .cardValues, correct: 8, total: 10, elapsedSeconds: 32)
        state.record(summary); state.record(summary)
        XCTAssertEqual(state.sessions.count, 1)
        XCTAssertEqual(state.trainingAccuracy, 0.8)
    }
    func testAccuracyUsesAllAnswersRatherThanUnweightedSessionAverage() {
        var state = StudioSnapshot()
        state.record(.init(kind: .cardValues, correct: 10, total: 10, elapsedSeconds: 25))
        state.record(.init(kind: .runningCount, correct: 0, total: 20, elapsedSeconds: 80))
        XCTAssertEqual(state.trainingAccuracy!, 1.0 / 3.0, accuracy: 0.00001)
    }
    func testInvalidSessionDoesNotEnterHistory() {
        var state = StudioSnapshot()
        state.record(.init(kind: .cardValues, correct: 5, total: 1, elapsedSeconds: 2))
        state.record(.init(kind: .cardValues, correct: 0, total: 0, elapsedSeconds: 2))
        state.record(.init(kind: .cardValues, correct: 1, total: 1, elapsedSeconds: .infinity))
        XCTAssertTrue(state.sessions.isEmpty)
    }
    func testDailyActivityRespectsChosenCalendarTimezone() {
        var state = StudioSnapshot()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: -5 * 3600)!
        let day = ISO8601DateFormatter().date(from: "2026-10-27T23:00:00Z")!
        state.record(.init(kind: .cardValues, correct: 10, total: 10, elapsedSeconds: 60, date: day))
        state.record(.init(kind: .pairs, correct: 10, total: 10, elapsedSeconds: 45, date: day.addingTimeInterval(3 * 3600)))
        XCTAssertEqual(state.practiceSeconds(on: day, calendar: calendar), 105)
        XCTAssertEqual(state.activeDays(ending: day, calendar: calendar).filter { $0 }.count, 1)
    }
    func testLegalDecisionsRecordOnceAndInvalidMovesDoNotCount() {
        var state = StudioSnapshot()
        state.game = GameState(seed: 1, shoe: [Card(rank: .ten, suit: .spades), Card(rank: .six, suit: .hearts), Card(rank: .eight, suit: .clubs), Card(rank: .nine, suit: .diamonds), Card(rank: .ten, suit: .clubs)])
        state.play(.stand)
        XCTAssertEqual(state.strategyDecisions, 0)
        state.play(.deal(betCents: 2_500))
        state.play(.split)
        XCTAssertEqual(state.strategyDecisions, 0)
        state.play(.stand)
        XCTAssertEqual(state.strategyDecisions, 1)
        XCTAssertEqual(state.correctDecisions, 1)
        XCTAssertEqual(state.game.bankrollCents, 102_500)
        state.play(.stand)
        XCTAssertEqual(state.strategyDecisions, 1)
    }
    func testRulesCannotDiscardActiveStake() {
        var state = StudioSnapshot()
        state.game = GameState(seed: 1, shoe: [Card(rank: .ten, suit: .spades), Card(rank: .six, suit: .hearts), Card(rank: .eight, suit: .clubs), Card(rank: .nine, suit: .diamonds), Card(rank: .ten, suit: .clubs)])
        state.play(.deal(betCents: 2_500))
        let before = state.game
        state.applyRules(Rules(decks: 8))
        XCTAssertEqual(state.game, before)
        state.play(.stand)
        state.applyRules(Rules(decks: 8))
        XCTAssertEqual(state.game.rules.decks, 8)
        XCTAssertEqual(state.game.bankrollCents, 102_500)
        XCTAssertEqual(state.game.rounds, 1)
    }
    func testAtomicStorageRecoversPreviousValidFile() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = StudioStorage(directory: directory)
        var state = StudioSnapshot()
        state.preferences.dailyMinutes = 3
        try storage.save(state)
        state.preferences.dailyMinutes = 10
        try storage.save(state)
        try Data("corrupt".utf8).write(to: directory.appendingPathComponent("practice.json"))
        let recovered = storage.load()
        XCTAssertTrue(recovered.recovered)
        XCTAssertEqual(recovered.snapshot.preferences.dailyMinutes, 3)
        try storage.erase()
        XCTAssertFalse(storage.load().recovered)
        XCTAssertTrue(storage.load().snapshot.sessions.isEmpty)
    }
    func testInvalidDataIsNeverWrittenOverValidProgress() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = StudioStorage(directory: directory)
        var state = StudioSnapshot()
        try storage.save(state)
        state.correctDecisions = 4
        XCTAssertThrowsError(try storage.save(state))
        XCTAssertTrue(storage.load().snapshot.isValid)
        XCTAssertEqual(storage.load().snapshot.correctDecisions, 0)
    }
    func testVersionOneProgressWithoutSimulationFieldsKeepsExistingData() throws {
        var state = StudioSnapshot()
        state.preferences.hasOnboarded = true
        state.preferences.dailyMinutes = 10
        state.preferences.experience = .refining
        state.completedLessons = ["hi-lo", "pairs"]
        state.selectedStake = 5_000
        state.strategyDecisions = 12
        state.correctDecisions = 9
        state.record(.init(kind: .cardValues, correct: 8, total: 10, elapsedSeconds: 32))
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        object.removeValue(forKey: "activeSimulation")
        object.removeValue(forKey: "simulationSessions")
        let data = try JSONSerialization.data(withJSONObject: object)
        let restored = try JSONDecoder().decode(StudioSnapshot.self, from: data)
        XCTAssertTrue(restored.isValid)
        XCTAssertEqual(restored.preferences, state.preferences)
        XCTAssertEqual(restored.completedLessons, state.completedLessons)
        XCTAssertEqual(restored.sessions, state.sessions)
        XCTAssertEqual(restored.selectedStake, 5_000)
        XCTAssertEqual(restored.accuracy, 0.75)
        XCTAssertEqual(restored.game, state.game)
        XCTAssertNil(restored.activeSimulation)
        XCTAssertTrue(restored.simulationSessions.isEmpty)
        object.removeValue(forKey: "game")
        XCTAssertThrowsError(try JSONDecoder().decode(StudioSnapshot.self, from: JSONSerialization.data(withJSONObject: object)))
    }

    func testSimulationHistoryIsSeparateDeduplicatedAndCountedAsPractice() throws {
        var state = StudioSnapshot()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: -5 * 3600)!
        let day = ISO8601DateFormatter().date(from: "2026-10-27T23:00:00Z")!
        let summary = try completedSimulation(date: day.addingTimeInterval(3 * 3600))
        XCTAssertEqual(summary.elapsedSeconds, 120)
        state.record(.init(kind: .cardValues, correct: 10, total: 10, elapsedSeconds: 60, date: day))
        state.record(summary)
        state.record(summary)
        XCTAssertTrue(state.isValid)
        XCTAssertEqual(state.simulationSessions.count, 1)
        XCTAssertEqual(state.strategyDecisions, 0)
        XCTAssertNil(state.accuracy)
        XCTAssertEqual(state.trainingAccuracy, 1)
        XCTAssertEqual(state.simulationStrategyAccuracy, summary.strategyAccuracy)
        XCTAssertEqual(state.simulationCountAccuracy, summary.countAccuracy)
        XCTAssertEqual(state.practiceSeconds(on: day, calendar: calendar), 60 + summary.elapsedSeconds)
        XCTAssertEqual(state.activeDays(ending: day, calendar: calendar).filter { $0 }.count, 1)
        state.sessions = []
        XCTAssertTrue(state.activeDays(ending: day, calendar: calendar).last!)
    }

    func testActiveSimulationRestoresAlongsideCompletedHistory() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = StudioStorage(directory: directory)
        var state = StudioSnapshot()
        state.record(try completedSimulation())
        var active = SimulationSession(configuration: .init(mode: .guided), seed: 17)
        active.startNextRound()
        active.recordPracticeTime(14)
        state.activeSimulation = active
        XCTAssertTrue(state.isValid)
        try storage.save(state)
        let restored = storage.load()
        XCTAssertFalse(restored.recovered)
        XCTAssertTrue(restored.snapshot.isValid)
        XCTAssertEqual(restored.snapshot.activeSimulation?.id, active.id)
        XCTAssertEqual(restored.snapshot.activeSimulation?.game, active.game)
        XCTAssertEqual(restored.snapshot.activeSimulation?.stage, active.stage)
        XCTAssertEqual(restored.snapshot.activeSimulation?.elapsedSeconds, 14)
        XCTAssertEqual(restored.snapshot.simulationSessions.first?.id, state.simulationSessions.first?.id)
        try storage.erase()
        let fresh = storage.load().snapshot
        XCTAssertNil(fresh.activeSimulation)
        XCTAssertTrue(fresh.simulationSessions.isEmpty)
    }

    func testInvalidSimulationRecordsCannotReplaceValidSavedProgress() throws {
        var state = StudioSnapshot()
        let summary = try completedSimulation()
        var malformed = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(summary)) as? [String: Any])
        malformed["completedRounds"] = 1
        let invalid = try JSONDecoder().decode(SimulationSummary.self, from: JSONSerialization.data(withJSONObject: malformed))
        XCTAssertFalse(invalid.isValidForRestore)
        state.record(invalid)
        XCTAssertTrue(state.simulationSessions.isEmpty)
        state.simulationSessions = [invalid]
        XCTAssertFalse(state.isValid)
        state.simulationSessions = [summary, summary]
        XCTAssertFalse(state.isValid)
        state.simulationSessions = [summary]
        let active = SimulationSession(configuration: .init(), seed: 17)
        var activeObject = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(active)) as? [String: Any])
        activeObject["completedRounds"] = 500
        state.activeSimulation = try JSONDecoder().decode(SimulationSession.self, from: JSONSerialization.data(withJSONObject: activeObject))
        XCTAssertFalse(state.isValid)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = StudioStorage(directory: directory)
        let valid = StudioSnapshot()
        try storage.save(valid)
        XCTAssertThrowsError(try storage.save(state))
        XCTAssertTrue(storage.load().snapshot.isValid)
        XCTAssertNil(storage.load().snapshot.activeSimulation)
    }

    func testSimulationHistoryKeepsNewestHundredSessionsByDate() throws {
        let template = try completedSimulation()
        let date = Date(timeIntervalSinceReferenceDate: 1_000)
        var state = StudioSnapshot()
        for offset in (0..<102).reversed() {
            state.record(SimulationSummary(date: date.addingTimeInterval(Double(offset)), configuration: template.configuration,
                completedRounds: template.completedRounds, decisions: template.decisions,
                countResponses: template.countResponses, elapsedSeconds: template.elapsedSeconds))
        }
        XCTAssertEqual(state.simulationSessions.count, 100)
        XCTAssertEqual(state.simulationSessions.first?.date, date.addingTimeInterval(2))
        XCTAssertEqual(state.simulationSessions.last?.date, date.addingTimeInterval(101))
        XCTAssertTrue(state.isValid)
    }

    private func completedSimulation(date: Date = Date()) throws -> SimulationSummary {
        var session = SimulationSession(configuration: .init(rounds: 10, mode: .test, countChecks: true), seed: 17)
        session.recordPracticeTime(120)
        for _ in 0..<1_000 {
            if session.stage == .complete { break }
            switch session.stage {
            case .ready: session.startNextRound()
            case .playing:
                session.play(session.game.phase == .insurance ? .declineInsurance : .stand)
            case .decisionFeedback: session.continueDecisionFeedback()
            case .roundReview: session.beginCountCheck()
            case .countCheck: session.submitCount(session.game.runningCount)
            case .countFeedback: session.finishRound()
            case .complete: break
            }
        }
        return try XCTUnwrap(session.summary(date: date))
    }

}

final class StudioPersistenceTests: XCTestCase {
    func testBackgroundSavesAndResetRemainOrdered() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = StudioStorage(directory: directory)
        let writer = StudioPersistence(storage: storage)
        var first = StudioSnapshot()
        first.completedLessons.insert("first")
        writer.save(first)
        writer.reset(to: StudioSnapshot())
        var latest = StudioSnapshot()
        latest.preferences.dailyMinutes = 10
        writer.save(latest)
        await writer.flush()
        XCTAssertTrue(storage.load().snapshot.completedLessons.isEmpty)
        XCTAssertEqual(storage.load().snapshot.preferences.dailyMinutes, 10)
        let old = try Data(contentsOf: directory.appendingPathComponent("practice.previous.json"))
        let backup = try JSONDecoder().decode(StudioSnapshot.self, from: old)
        XCTAssertTrue(backup.completedLessons.isEmpty)
    }
}
