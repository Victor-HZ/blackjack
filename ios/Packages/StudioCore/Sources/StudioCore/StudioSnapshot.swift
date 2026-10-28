import Foundation
import BlackjackCore
import TrainingCore

public enum Experience: String, CaseIterable, Codable, Sendable {
    case starting, familiar, refining
    public var title: String {
        switch self {
        case .starting: return "Starting fresh"
        case .familiar: return "Know the basics"
        case .refining: return "Building consistency"
        }
    }
    public var subtitle: String {
        switch self {
        case .starting: return "Learn the values. Find your rhythm."
        case .familiar: return "Make the count second nature."
        case .refining: return "Sharpen accuracy and pace."
        }
    }
}

public struct StudioPreferences: Codable, Equatable, Sendable {
    public var hasOnboarded = false
    public var experience: Experience = .starting
    public var dailyMinutes = 5
    public var haptics = true
    public var showCoach = true
    public var showCount = false
    public var reminderEnabled = false
    public var reminderHour = 19
    public init() {}
}

public struct StudioSnapshot: Codable, Sendable {
    public var version = 1
    public var preferences = StudioPreferences()
    public var game = GameState()
    public var sessions: [DrillSummary] = []
    public var activeSimulation: SimulationSession?
    public var simulationSessions: [SimulationSummary] = []
    public var completedLessons: Set<String> = []
    public var strategyDecisions = 0
    public var correctDecisions = 0
    public var selectedStake = 2_500
    public init() {}

    private enum CodingKeys: String, CodingKey {
        case version, preferences, game, sessions, completedLessons, strategyDecisions, correctDecisions, selectedStake
        case activeSimulation, simulationSessions
    }
    /// Existing version-one progress remains readable when simulation fields are absent.
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        version = try values.decode(Int.self, forKey: .version)
        preferences = try values.decode(StudioPreferences.self, forKey: .preferences)
        game = try values.decode(GameState.self, forKey: .game)
        sessions = try values.decode([DrillSummary].self, forKey: .sessions)
        completedLessons = try values.decode(Set<String>.self, forKey: .completedLessons)
        strategyDecisions = try values.decode(Int.self, forKey: .strategyDecisions)
        correctDecisions = try values.decode(Int.self, forKey: .correctDecisions)
        selectedStake = try values.decode(Int.self, forKey: .selectedStake)
        activeSimulation = try values.decodeIfPresent(SimulationSession.self, forKey: .activeSimulation)
        simulationSessions = try values.decodeIfPresent([SimulationSummary].self, forKey: .simulationSessions) ?? []
    }
    public var isValid: Bool {
        version == 1 && game.isValidForRestore
        && [3, 5, 10].contains(preferences.dailyMinutes)
        && (0...23).contains(preferences.reminderHour)
        && (0...1_000_000_000).contains(strategyDecisions)
        && (0...strategyDecisions).contains(correctDecisions)
        && (100...1_000_000_000).contains(selectedStake)
        && sessions.count <= 1_000 && Set(sessions.map(\.id)).count == sessions.count
        && sessions.allSatisfy(\.isValidForRestore)
        && (activeSimulation?.isValidForRestore ?? true)
        && simulationSessions.count <= 100
        && Set(simulationSessions.map(\.id)).count == simulationSessions.count
        && simulationSessions.allSatisfy(\.isValidForRestore)
        && completedLessons.count <= 100 && completedLessons.allSatisfy { !$0.isEmpty && $0.count < 100 }
    }
    public var accuracy: Double? { strategyDecisions == 0 ? nil : Double(correctDecisions) / Double(strategyDecisions) }
    public var trainingAccuracy: Double? {
        let total = sessions.reduce(0) { $0 + $1.total }
        guard total > 0 else { return nil }
        return Double(sessions.reduce(0) { $0 + $1.correct }) / Double(total)
    }
    public var simulationStrategyAccuracy: Double? {
        let decisions = simulationSessions.flatMap(\.decisions)
        guard !decisions.isEmpty else { return nil }
        return Double(decisions.filter(\.correct).count) / Double(decisions.count)
    }
    public var simulationCountAccuracy: Double? {
        let responses = simulationSessions.flatMap(\.countResponses)
        guard !responses.isEmpty else { return nil }
        return Double(responses.filter(\.correct).count) / Double(responses.count)
    }
    public func practiceSeconds(on date: Date, calendar: Calendar = .current) -> Double {
        let drills = sessions.filter { calendar.isDate($0.date, inSameDayAs: date) }.reduce(0) { $0 + $1.elapsedSeconds }
        let simulations = simulationSessions.filter { calendar.isDate($0.date, inSameDayAs: date) }.reduce(0) { $0 + $1.elapsedSeconds }
        return drills + simulations
    }
    public func activeDays(ending date: Date, calendar: Calendar = .current) -> [Bool] {
        (0..<7).reversed().map { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: date) else { return false }
            return sessions.contains { calendar.isDate($0.date, inSameDayAs: day) }
                || simulationSessions.contains { calendar.isDate($0.date, inSameDayAs: day) }
        }
    }
    public mutating func record(_ summary: DrillSummary) {
        guard !sessions.contains(where: { $0.id == summary.id }), summary.isValidForRestore else { return }
        sessions.append(summary)
        sessions = Array(sessions.suffix(1_000))
    }
    public mutating func record(_ summary: SimulationSummary) {
        guard summary.isValidForRestore, !simulationSessions.contains(where: { $0.id == summary.id }) else { return }
        simulationSessions.append(summary)
        simulationSessions.sort { lhs, rhs in
            lhs.date == rhs.date ? lhs.id.uuidString < rhs.id.uuidString : lhs.date < rhs.date
        }
        simulationSessions = Array(simulationSessions.suffix(100))
    }
    public mutating func play(_ action: GameAction) {
        let next = GameEngine.reduce(game, action)
        guard next != game else { return }
        if let move = action.move, GameEngine.availableMoves(in: game).contains(move),
           let advice = BasicStrategy.recommend(in: game) {
            strategyDecisions += 1
            if advice.move == move { correctDecisions += 1 }
        }
        game = next
    }
    public mutating func applyRules(_ rules: Rules) {
        guard !game.isRoundActive else { return }
        var fresh = GameState(bankrollCents: game.bankrollCents, rules: rules)
        fresh.rounds = game.rounds
        fresh.history = game.history
        game = fresh
    }
    public mutating func resetTable() {
        game = GameState(rules: game.rules)
        strategyDecisions = 0
        correctDecisions = 0
        selectedStake = 2_500
    }
}

/// Local, atomic storage; a previous valid file supports recovery after an interrupted write.
public struct StudioStorage: Sendable {
    public let directory: URL
    public init(directory: URL) { self.directory = directory }
    private var primary: URL { directory.appendingPathComponent("practice.json") }
    private var backup: URL { directory.appendingPathComponent("practice.previous.json") }
    public struct LoadResult { public var snapshot: StudioSnapshot; public var recovered: Bool }
    private func decoded(_ url: URL) -> StudioSnapshot? {
        guard let data = try? Data(contentsOf: url), data.count <= 32_000_000,
              let value = try? JSONDecoder().decode(StudioSnapshot.self, from: data), value.isValid else { return nil }
        return value
    }
    public func load() -> LoadResult {
        if let value = decoded(primary) { return .init(snapshot: value, recovered: false) }
        if let value = decoded(backup) { return .init(snapshot: value, recovered: true) }
        return .init(snapshot: StudioSnapshot(), recovered: FileManager.default.fileExists(atPath: primary.path))
    }
    public func save(_ snapshot: StudioSnapshot) throws {
        guard snapshot.isValid else { throw StorageError.invalidState }
        let encoded = try JSONEncoder().encode(snapshot)
        guard encoded.count <= 32_000_000 else { throw StorageError.invalidState }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if let old = decoded(primary) {
            try JSONEncoder().encode(old).write(to: backup, options: .atomic)
        }
        try encoded.write(to: primary, options: .atomic)
    }
    public func erase() throws {
        for url in [primary, backup] where FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
    public enum StorageError: Error { case invalidState }
}

/// Enqueues disk operations synchronously in submission order, then performs IO off the UI actor.
public final class StudioPersistence: @unchecked Sendable {
    private let storage: StudioStorage
    private let queue = DispatchQueue(label: "studio.local-storage", qos: .utility)
    public init(storage: StudioStorage) { self.storage = storage }
    public func save(_ snapshot: StudioSnapshot, completion: @escaping @Sendable (Result<Void, Error>) -> Void = { _ in }) {
        queue.async { [storage] in
            do { try storage.save(snapshot); completion(.success(())) }
            catch { completion(.failure(error)) }
        }
    }
    public func reset(to snapshot: StudioSnapshot, completion: @escaping @Sendable (Result<Void, Error>) -> Void = { _ in }) {
        queue.async { [storage] in
            do { try storage.erase(); try storage.save(snapshot); completion(.success(())) }
            catch { completion(.failure(error)) }
        }
    }
    public func flush() async {
        await withCheckedContinuation { continuation in queue.async { continuation.resume() } }
    }
}
