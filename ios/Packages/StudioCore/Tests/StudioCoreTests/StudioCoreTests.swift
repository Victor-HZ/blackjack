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
