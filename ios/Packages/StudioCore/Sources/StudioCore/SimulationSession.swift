import Foundation
import BlackjackCore
import TrainingCore

public enum SimulationMode: String, CaseIterable, Codable, Sendable {
    case guided, test
    public var title: String { self == .guided ? "Guided practice" : "Skill test" }
}

public struct SimulationConfiguration: Codable, Equatable, Sendable {
    public let rounds: Int
    public let mode: SimulationMode
    public let countChecks: Bool
    public let rules: Rules
    public init(rounds: Int = 10, mode: SimulationMode = .guided, countChecks: Bool = true, rules: Rules = .standard) {
        self.rounds = [10, 25, 50].contains(rounds) ? rounds : 10
        self.mode = mode
        self.countChecks = countChecks
        self.rules = rules.isSupported ? rules : .standard
    }
    public var isValidForRestore: Bool { [10, 25, 50].contains(rounds) && rules.isSupported }
}

public enum SimulationStage: String, Codable, Sendable {
    case ready, playing, decisionFeedback, roundReview, countCheck, countFeedback, complete
}

public enum SimulationTopic: String, CaseIterable, Codable, Sendable {
    case hard, soft, pairs, insurance
    public var title: String {
        switch self {
        case .hard: return "Hard hands"
        case .soft: return "Soft hands"
        case .pairs: return "Pairs"
        case .insurance: return "Insurance"
        }
    }
}

/// Includes insurance choices, which are decisions but not ordinary player moves.
public enum SimulationChoice: String, CaseIterable, Codable, Sendable {
    case hit, stand, doubleDown, split, surrender, insurance, declineInsurance
    public init?(_ action: GameAction) {
        switch action {
        case .hit: self = .hit
        case .stand: self = .stand
        case .doubleDown: self = .doubleDown
        case .split: self = .split
        case .surrender: self = .surrender
        case .insurance: self = .insurance
        case .declineInsurance: self = .declineInsurance
        default: return nil
        }
    }
    public var title: String {
        switch self {
        case .hit: return "Hit"
        case .stand: return "Stand"
        case .doubleDown: return "Double"
        case .split: return "Split"
        case .surrender: return "Surrender"
        case .insurance: return "Take insurance"
        case .declineInsurance: return "Decline insurance"
        }
    }
    public var gameAction: GameAction {
        switch self {
        case .hit: return .hit
        case .stand: return .stand
        case .doubleDown: return .doubleDown
        case .split: return .split
        case .surrender: return .surrender
        case .insurance: return .insurance
        case .declineInsurance: return .declineInsurance
        }
    }
}

/// The exact visible hand and legal choices at the first attempt. Dealer contains only its upcard.
public struct SimulationDecision: Codable, Equatable, Identifiable, Sendable {
    public let id: Int
    public let round: Int
    public let cards: [Card]
    public let dealer: Card
    public let rules: Rules
    public let availableChoices: [SimulationChoice]
    public let chosen: SimulationChoice
    public let recommended: SimulationChoice
    public let topic: SimulationTopic
    public let explanation: String
    public let fromSplit: Bool
    public var correct: Bool { chosen == recommended }
    public init(id: Int, round: Int, cards: [Card], dealer: Card, rules: Rules, availableChoices: [SimulationChoice], chosen: SimulationChoice, recommended: SimulationChoice, topic: SimulationTopic, explanation: String, fromSplit: Bool = false) {
        self.id = id; self.round = round; self.cards = cards; self.dealer = dealer; self.rules = rules
        self.availableChoices = availableChoices; self.chosen = chosen; self.recommended = recommended
        self.topic = topic; self.explanation = explanation; self.fromSplit = fromSplit
    }
    public var isValidForRestore: Bool {
        guard (0..<6_400).contains(id), (1...50).contains(round), (2...32).contains(cards.count),
              rules.isSupported, !explanation.isEmpty, explanation.count <= 2_000,
              (1...7).contains(availableChoices.count), Set(availableChoices).count == availableChoices.count,
              availableChoices.contains(chosen), availableChoices.contains(recommended) else { return false }
        if topic == .insurance {
            return cards.count == 2 && dealer.rank == .ace && !fromSplit
                && availableChoices == [.declineInsurance, .insurance]
                && recommended == .declineInsurance
        }
        guard HandValue.evaluate(cards).total < 21,
              !availableChoices.contains(.insurance), !availableChoices.contains(.declineInsurance),
              availableChoices.contains(.hit), availableChoices.contains(.stand),
              topic == Self.topic(for: cards) else { return false }
        if availableChoices.contains(.doubleDown) && (cards.count != 2 || (fromSplit && !rules.doubleAfterSplit)) { return false }
        if availableChoices.contains(.split) && (cards.count != 2 || cards[0].value != cards[1].value) { return false }
        if availableChoices.contains(.surrender) && (cards.count != 2 || fromSplit || !rules.surrender) { return false }
        let advice = BasicStrategy.recommend(cards: cards, dealer: dealer, rules: rules,
            options: StrategyOptions(canDouble: availableChoices.contains(.doubleDown), canSplit: availableChoices.contains(.split),
                                     canSurrender: availableChoices.contains(.surrender), fromSplit: fromSplit))
        return SimulationChoice(advice.move.action) == recommended
    }
    fileprivate static func topic(for cards: [Card]) -> SimulationTopic {
        if cards.count == 2 && cards[0].value == cards[1].value { return .pairs }
        return HandValue.evaluate(cards).soft ? .soft : .hard
    }
}

public struct SimulationCountResponse: Codable, Equatable, Identifiable, Sendable {
    public let round: Int
    public let expectedCount: Int
    public let answer: Int
    public var id: Int { round }
    public var correct: Bool { answer == expectedCount }
    public init(round: Int, expectedCount: Int, answer: Int) {
        self.round = round; self.expectedCount = expectedCount; self.answer = answer
    }
    public var isValidForRestore: Bool {
        (1...50).contains(round) && (-416...416).contains(expectedCount) && (-416...416).contains(answer)
    }
}

public struct SimulationSummary: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let date: Date
    public let configuration: SimulationConfiguration
    public let completedRounds: Int
    public let decisions: [SimulationDecision]
    public let countResponses: [SimulationCountResponse]
    public let elapsedSeconds: Double
    public init(id: UUID = UUID(), date: Date = Date(), configuration: SimulationConfiguration, completedRounds: Int,
                decisions: [SimulationDecision], countResponses: [SimulationCountResponse], elapsedSeconds: Double = 0) {
        self.id = id; self.date = date; self.configuration = configuration; self.completedRounds = completedRounds
        self.decisions = decisions; self.countResponses = countResponses; self.elapsedSeconds = elapsedSeconds
    }
    public var strategyAccuracy: Double? {
        decisions.isEmpty ? nil : Double(decisions.filter(\.correct).count) / Double(decisions.count)
    }
    public var countAccuracy: Double? {
        countResponses.isEmpty ? nil : Double(countResponses.filter(\.correct).count) / Double(countResponses.count)
    }
    public var mistakes: [SimulationDecision] { decisions.filter { !$0.correct } }
    public var countMistakes: [SimulationCountResponse] { countResponses.filter { !$0.correct } }
    /// Prioritize the topic with the most missed decisions; enum order makes ties stable.
    public var weakestTopic: SimulationTopic? {
        SimulationTopic.allCases.max { first, second in
            mistakes.filter { $0.topic == first }.count < mistakes.filter { $0.topic == second }.count
        }.flatMap { topic in mistakes.contains { $0.topic == topic } ? topic : nil }
    }
    public var suggestedDrill: DrillKind? { countMistakes.isEmpty ? nil : .runningCount }
    public var isValidForRestore: Bool {
        guard configuration.isValidForRestore, completedRounds == configuration.rounds,
              date.timeIntervalSinceReferenceDate.isFinite,
              elapsedSeconds.isFinite, (0...86_400).contains(elapsedSeconds),
              validDecisions(decisions, rounds: completedRounds, rules: configuration.rules),
              validCounts(countResponses, rounds: configuration.countChecks ? completedRounds : 0) else { return false }
        return true
    }
}

/// A finite, scored practice session. Every action and checkpoint is accepted once.
/// This uses simulated cards only; there is no live-game card input or wagering advice.
public struct SimulationSession: Codable, Sendable, Identifiable {
    public let id: UUID
    public let configuration: SimulationConfiguration
    public private(set) var game: GameState
    public private(set) var stage: SimulationStage = .ready
    public private(set) var decisions: [SimulationDecision] = []
    public private(set) var countResponses: [SimulationCountResponse] = []
    public private(set) var completedRounds = 0
    public private(set) var shoeNumber = 1
    public private(set) var roundStartedNewShoe = true
    public private(set) var shoeChangedDuringRound = false
    public private(set) var elapsedSeconds: Double = 0

    public init(configuration: SimulationConfiguration = .init(), seed: UInt64 = UInt64.random(in: 0...UInt64.max), shoe: [Card]? = nil) {
        id = UUID()
        self.configuration = configuration.isValidForRestore ? configuration : .init()
        // At most 8 units + insurance can be lost per round. 1,000 units safely covers all 50 rounds.
        game = GameState(bankrollCents: 100_000, rules: self.configuration.rules, seed: seed, shoe: shoe)
        // Reserve an entire round before dealing, including four split hands and a
        // dealer hit on soft 17. A 64-card reserve covers the four-deck worst case;
        // the ordinary six/eight-deck cuts are already larger.
        game.cutCard = max(64, game.cutCard)
    }
    public var currentRound: Int { min(completedRounds + 1, configuration.rounds) }
    public var availableChoices: [SimulationChoice] {
        guard stage == .playing else { return [] }
        if game.phase == .insurance { return [.declineInsurance, .insurance] }
        return GameEngine.availableMoves(in: game).compactMap { SimulationChoice($0.action) }
    }
    public var lastDecision: SimulationDecision? { decisions.last }
    public var lastCountResponse: SimulationCountResponse? { countResponses.last }

    @discardableResult public mutating func startNextRound() -> Bool {
        guard isValidForRestore, stage == .ready else { return false }
        let previousSeed = game.seed
        let next = GameEngine.reduce(game, .deal(betCents: 100))
        guard next != game else { return false }
        game = next
        game.cutCard = max(64, game.cutCard)
        roundStartedNewShoe = completedRounds == 0 || previousSeed != game.seed
        shoeChangedDuringRound = false
        if previousSeed != game.seed { shoeNumber += 1 }
        stage = game.phase == .settled ? .roundReview : .playing
        return true
    }
    @discardableResult public mutating func play(_ action: GameAction) -> Bool {
        guard isValidForRestore, let chosen = SimulationChoice(action), availableChoices.contains(chosen),
              let hand = game.currentHand, let dealer = game.dealer.first else { return false }
        let legalChoices = availableChoices
        let recommended: SimulationChoice
        let reason: String
        let topic: SimulationTopic
        if game.phase == .insurance {
            recommended = .declineInsurance
            reason = "Basic strategy declines insurance. It is a separate side bet, not protection for your hand."
            topic = .insurance
        } else {
            guard let advice = BasicStrategy.recommend(in: game), let choice = SimulationChoice(advice.move.action) else { return false }
            recommended = choice; reason = advice.reason; topic = SimulationDecision.topic(for: hand.cards)
        }
        let next = GameEngine.reduce(game, action)
        guard next != game else { return false }
        decisions.append(SimulationDecision(id: decisions.count, round: currentRound, cards: hand.cards, dealer: dealer,
            rules: game.rules, availableChoices: legalChoices, chosen: chosen, recommended: recommended,
            topic: topic, explanation: reason, fromSplit: hand.fromSplit))
        if next.seed != game.seed { shoeNumber += 1; shoeChangedDuringRound = true }
        game = next
        game.cutCard = max(64, game.cutCard)
        stage = configuration.mode == .guided ? .decisionFeedback : (game.phase == .settled ? .roundReview : .playing)
        return true
    }
    @discardableResult public mutating func continueDecisionFeedback() -> Bool {
        guard isValidForRestore, stage == .decisionFeedback else { return false }
        stage = game.phase == .settled ? .roundReview : .playing
        return true
    }
    @discardableResult public mutating func beginCountCheck() -> Bool {
        guard isValidForRestore, stage == .roundReview, configuration.countChecks else { return false }
        stage = .countCheck
        return true
    }
    @discardableResult public mutating func submitCount(_ answer: Int) -> Bool {
        guard isValidForRestore, stage == .countCheck, (-416...416).contains(answer) else { return false }
        countResponses.append(.init(round: currentRound, expectedCount: game.runningCount, answer: answer))
        stage = .countFeedback
        return true
    }
    @discardableResult public mutating func finishRound() -> Bool {
        guard isValidForRestore, (stage == .roundReview && !configuration.countChecks) || stage == .countFeedback else { return false }
        completedRounds += 1
        stage = completedRounds == configuration.rounds ? .complete : .ready
        return true
    }
    /// Call with foreground, monotonic time only. No background or wall-clock interval is inferred.
    @discardableResult public mutating func recordPracticeTime(_ seconds: Double) -> Bool {
        guard isValidForRestore, stage != .complete, seconds.isFinite, seconds >= 0 else { return false }
        elapsedSeconds = min(86_400, elapsedSeconds + min(seconds, 86_400))
        return true
    }
    public func summary(date: Date = Date()) -> SimulationSummary? {
        guard stage == .complete, isValidForRestore, date.timeIntervalSinceReferenceDate.isFinite else { return nil }
        return SimulationSummary(id: id, date: date, configuration: configuration, completedRounds: completedRounds,
                                 decisions: decisions, countResponses: countResponses, elapsedSeconds: elapsedSeconds)
    }
    public var isValidForRestore: Bool {
        guard configuration.isValidForRestore, game.isValidForRestore, game.rules == configuration.rules,
              (0...configuration.rounds).contains(completedRounds),
              elapsedSeconds.isFinite, (0...86_400).contains(elapsedSeconds),
              (1...6_401).contains(shoeNumber), game.cutCard >= 64,
              game.history.count == game.rounds,
              game.history.enumerated().allSatisfy({ $0.element.id == $0.offset + 1 }),
              validSimulationLedger(game),
              validDecisions(decisions, rounds: stage == .ready || stage == .complete ? completedRounds : min(completedRounds + 1, configuration.rounds), rules: configuration.rules),
              validCounts(countResponses, rounds: configuration.countChecks ? completedRounds + (stage == .countFeedback ? 1 : 0) : 0) else { return false }
        if game.phase == .playing && game.hands.contains(where: { $0.status == .playing && $0.value.total >= 21 }) { return false }
        if !configuration.countChecks && (stage == .countCheck || stage == .countFeedback) { return false }
        if configuration.countChecks, [.countFeedback, .ready, .complete].contains(stage),
           let response = countResponses.last, response.expectedCount != game.runningCount { return false }
        switch stage {
        case .ready:
            return completedRounds < configuration.rounds && game.rounds == completedRounds
                && (completedRounds == 0 ? game.phase == .betting : game.phase == .settled)
        case .playing:
            return completedRounds < configuration.rounds && game.rounds == completedRounds && game.isRoundActive
        case .decisionFeedback:
            return configuration.mode == .guided && completedRounds < configuration.rounds
                && decisions.last?.round == completedRounds + 1
                && ((game.isRoundActive && game.rounds == completedRounds) || (game.phase == .settled && game.rounds == completedRounds + 1))
        case .roundReview, .countCheck, .countFeedback:
            return completedRounds < configuration.rounds && game.phase == .settled && game.rounds == completedRounds + 1
        case .complete:
            return completedRounds == configuration.rounds && game.phase == .settled && game.rounds == completedRounds
        }
    }
}

private func validDecisions(_ decisions: [SimulationDecision], rounds: Int, rules: Rules) -> Bool {
    guard (0...50).contains(rounds), decisions.count <= rounds * 128 else { return false }
    var previousRound = 0
    var perRound = 0
    var insuranceSeen = false
    for (index, decision) in decisions.enumerated() {
        guard decision.isValidForRestore, decision.id == index, decision.rules == rules,
              decision.round <= rounds, decision.round >= previousRound else { return false }
        if decision.round != previousRound { previousRound = decision.round; perRound = 0; insuranceSeen = false }
        perRound += 1
        guard perRound <= 128 else { return false }
        if decision.topic == .insurance {
            guard !insuranceSeen, perRound == 1 else { return false }
            insuranceSeen = true
        }
    }
    return true
}

private func validCounts(_ counts: [SimulationCountResponse], rounds: Int) -> Bool {
    guard (0...50).contains(rounds), counts.count == rounds else { return false }
    return counts.enumerated().allSatisfy { $0.element.isValidForRestore && $0.element.round == $0.offset + 1 }
}

/// The fixed one-unit stake makes the session ledger fully checkable on restore.
/// This also prevents a corrupted save from restoring into an unfunded, stuck round.
private func validSimulationLedger(_ game: GameState) -> Bool {
    guard game.history.count <= 50, game.hands.allSatisfy({ [100, 200].contains($0.betCents) }),
          [0, 50].contains(game.insuranceBetCents), [0, 150].contains(game.insurancePayoutCents) else { return false }
    var balance = 100_000
    for result in game.history {
        guard (100...850).contains(result.betCents), result.betCents % 50 == 0,
              (-850...1_700).contains(result.profitCents), result.profitCents >= -result.betCents else { return false }
        balance += result.profitCents
        guard result.bankrollCents == balance else { return false }
    }
    let committed = game.isRoundActive ? game.hands.reduce(game.insuranceBetCents) { $0 + $1.betCents } : 0
    return game.bankrollCents == balance - committed
}
