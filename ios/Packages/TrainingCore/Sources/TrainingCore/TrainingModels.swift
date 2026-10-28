import Foundation

public enum DrillKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case cardValues, pairs, runningCount, fullDeck, trueCount, deckEstimation
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .cardValues: return "Card values"
        case .pairs: return "Pair cancellation"
        case .runningCount: return "Running count"
        case .fullDeck: return "Shoe stamina"
        case .trueCount: return "True count"
        case .deckEstimation: return "Deck estimation"
        }
    }
    public var subtitle: String {
        switch self {
        case .cardValues: return "Make +1, 0, and −1 automatic."
        case .pairs: return "See the sum, not two separate cards."
        case .runningCount: return "Keep the total as cards appear."
        case .fullDeck: return "Hold your count through a full deck."
        case .trueCount: return "Adjust the count for the cards left."
        case .deckEstimation: return "Learn to read a stack in half decks."
        }
    }
    public var durationLabel: String {
        switch self {
        case .cardValues, .pairs: return "1 min"
        case .runningCount, .trueCount, .deckEstimation: return "2 min"
        case .fullDeck: return "3 min"
        }
    }
    public var isPremium: Bool { ![.cardValues, .runningCount].contains(self) }
    public var symbol: String {
        switch self {
        case .cardValues: return "suit.spade.fill"
        case .pairs: return "rectangle.on.rectangle"
        case .runningCount: return "plus.forwardslash.minus"
        case .fullDeck: return "rectangle.stack.fill"
        case .trueCount: return "divide"
        case .deckEstimation: return "square.stack.3d.up"
        }
    }
    public var answerLabel: String {
        switch self {
        case .cardValues: return "What’s this card worth?"
        case .pairs: return "What’s the pair worth?"
        case .runningCount, .fullDeck: return "What’s the running count?"
        case .trueCount: return "What’s the true count?"
        case .deckEstimation: return "How many decks remain?"
        }
    }
    public var shortInstructions: String {
        switch self {
        case .cardValues: return "2–6: +1 · 7–9: 0 · 10–A: −1"
        case .pairs: return "Add the two Hi-Lo values."
        case .runningCount: return "Start at zero. Keep a running total."
        case .fullDeck: return "Count every group. Check your total after each one."
        case .trueCount: return "Running count ÷ decks left. Drop the decimal toward zero."
        case .deckEstimation: return "Use the full-deck marker. Estimate to the nearest half deck."
        }
    }
}

public struct TrainingCard: Codable, Equatable, Sendable, Identifiable {
    public var rank: String
    public var suit: String
    public var id: String { rank + suit }
    public var isRed: Bool { suit == "♥" || suit == "♦" }
    public var hiLo: Int {
        switch rank {
        case "2", "3", "4", "5", "6": return 1
        case "7", "8", "9": return 0
        default: return -1
        }
    }
    public var accessibilityName: String {
        let rankNames = ["A": "ace", "J": "jack", "Q": "queen", "K": "king"]
        let suits = ["♠": "spades", "♥": "hearts", "♦": "diamonds", "♣": "clubs"]
        return "\(rankNames[rank] ?? rank) of \(suits[suit] ?? suit)"
    }
    public init(rank: String, suit: String) { self.rank = rank; self.suit = suit }
}

public struct DrillPrompt: Identifiable, Codable, Equatable, Sendable {
    public let id: Int
    public let kind: DrillKind
    public let cards: [TrainingCard]
    public let expectedAnswer: Double
    public let runningCount: Int?
    public let decksRemaining: Double?
    public let cardsSeen: Int
    public let explanation: String
    public let previousCount: Int?
    public var formattedAnswer: String { Self.format(expectedAnswer, signed: kind != .deckEstimation) }
    public static func format(_ number: Double, signed: Bool = false) -> String {
        guard number.isFinite else { return "—" }
        let value = abs(number) <= 1_000_000 && number == number.rounded() ? String(Int(number)) : String(format: "%.1f", number)
        return signed && number > 0 ? "+" + value : value
    }
    public init(id: Int, kind: DrillKind, cards: [TrainingCard] = [], expectedAnswer: Double, runningCount: Int? = nil, decksRemaining: Double? = nil, cardsSeen: Int = 0, explanation: String, previousCount: Int? = nil) {
        self.id = id; self.kind = kind; self.cards = cards; self.expectedAnswer = expectedAnswer
        self.runningCount = runningCount; self.decksRemaining = decksRemaining; self.cardsSeen = cardsSeen
        self.explanation = explanation; self.previousCount = previousCount
    }
}

public struct DrillResponse: Codable, Equatable, Sendable, Identifiable {
    public let id: Int
    public let prompt: DrillPrompt
    public let answer: Double
    public let correct: Bool
    public let elapsedSeconds: Double
    public init(prompt: DrillPrompt, answer: Double, elapsedSeconds: Double) {
        id = prompt.id; self.prompt = prompt; self.answer = answer
        correct = abs(answer - prompt.expectedAnswer) < 0.001
        self.elapsedSeconds = max(0, elapsedSeconds)
    }
}

public struct DrillSummary: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let kind: DrillKind
    public let correct: Int
    public let total: Int
    public let elapsedSeconds: Double
    public let date: Date
    public let mistakes: [DrillResponse]
    public var accuracy: Double { total > 0 ? Double(correct) / Double(total) : 0 }
    public var accuracyPercent: Int { Int((accuracy * 100).rounded()) }
    public var secondsPerAnswer: Double { total > 0 ? elapsedSeconds / Double(total) : 0 }
    /// Saved summaries must be validated before presentation or progress aggregation.
    public var isValidForRestore: Bool {
        guard total > 0, total <= 1_000, correct >= 0, correct <= total,
              elapsedSeconds.isFinite, elapsedSeconds >= 0, elapsedSeconds < 86_400,
              date.timeIntervalSinceReferenceDate.isFinite,
              mistakes.count <= total - correct,
              Set(mistakes.map(\.id)).count == mistakes.count else { return false }
        let validRanks = Set(["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"])
        let validSuits = Set(["♠", "♥", "♦", "♣"])
        return mistakes.allSatisfy { response in
            let prompt = response.prompt
            guard response.id >= 0, response.id < 1_000, response.id == prompt.id,
                  !response.correct, response.answer.isFinite, abs(response.answer) <= 1_000,
                  response.elapsedSeconds.isFinite, response.elapsedSeconds >= 0, response.elapsedSeconds < 86_400,
                  prompt.kind == kind, prompt.expectedAnswer.isFinite, abs(prompt.expectedAnswer) <= 1_000,
                  abs(response.answer - prompt.expectedAnswer) >= 0.001,
                  prompt.cards.count <= 52, (0...416).contains(prompt.cardsSeen),
                  prompt.cards.allSatisfy({ validRanks.contains($0.rank) && validSuits.contains($0.suit) }),
                  prompt.explanation.count <= 2_000 else { return false }
            if let count = prompt.runningCount, !(-416...416).contains(count) { return false }
            if let count = prompt.previousCount, !(-416...416).contains(count) { return false }
            if let decks = prompt.decksRemaining, !decks.isFinite || decks < 0.5 || decks > 8 { return false }
            return true
        }
    }
    public var nextSuggestion: String {
        if accuracy >= 0.95 { return "Accurate and consistent. Try a little more pace next time." }
        if accuracy >= 0.75 { return "You’re close. Repeat this drill before adding speed." }
        return "Slow the pace. Accuracy comes before speed."
    }
    public init(id: UUID = UUID(), kind: DrillKind, correct: Int, total: Int, elapsedSeconds: Double, date: Date = Date(), mistakes: [DrillResponse] = []) {
        self.id = id; self.kind = kind; self.correct = correct; self.total = total
        self.elapsedSeconds = elapsedSeconds; self.date = date; self.mistakes = mistakes
    }
}

/// Keeps generated prompts separate from the UI. No real-world card-entry mode is provided.
public struct DrillSession: Codable, Sendable {
    public let id: UUID
    public let kind: DrillKind
    public let prompts: [DrillPrompt]
    public private(set) var index: Int = 0
    public private(set) var responses: [DrillResponse] = []
    public var currentPrompt: DrillPrompt? { prompts.indices.contains(index) ? prompts[index] : nil }
    public var currentResponse: DrillResponse? { responses.first(where: { $0.id == currentPrompt?.id }) }
    public var isComplete: Bool { index >= prompts.count }
    public var correct: Int { responses.filter(\.correct).count }
    public init(kind: DrillKind, seed: UInt64 = UInt64.random(in: 1...UInt64.max)) {
        id = UUID(); self.kind = kind; prompts = PromptFactory.make(kind: kind, seed: seed)
    }
    @discardableResult public mutating func submit(answer: Double, elapsedSeconds: Double) -> DrillResponse? {
        guard answer.isFinite, elapsedSeconds.isFinite, elapsedSeconds >= 0, elapsedSeconds < 86_400, let prompt = currentPrompt, currentResponse == nil else { return nil }
        let response = DrillResponse(prompt: prompt, answer: answer, elapsedSeconds: elapsedSeconds)
        responses.append(response)
        return response
    }
    @discardableResult public mutating func advance() -> Bool {
        guard currentResponse != nil else { return false }
        index += 1
        return true
    }
    public func summary(date: Date = Date()) -> DrillSummary {
        DrillSummary(id: id, kind: kind, correct: correct, total: responses.count,
                     elapsedSeconds: responses.reduce(0) { $0 + $1.elapsedSeconds }, date: date,
                     mistakes: responses.filter { !$0.correct })
    }
}

public enum TrainingRecommendation {
    /// Recommend a recent weak skill first, then the next accessible skill.
    public static func next(history: [DrillSummary], hasPro: Bool) -> DrillKind {
        let available = DrillKind.allCases.filter { hasPro || !$0.isPremium }
        let recent = history.sorted { $0.date > $1.date }.prefix(20)
        if let weakest = available.compactMap({ kind -> (DrillKind, Double)? in
            let attempts = recent.filter { $0.kind == kind && $0.total > 0 }
            guard !attempts.isEmpty else { return nil }
            return (kind, Double(attempts.reduce(0) { $0 + $1.correct }) / Double(attempts.reduce(0) { $0 + $1.total }))
        }).filter({ $0.1 < 0.9 }).min(by: { $0.1 < $1.1 }) { return weakest.0 }
        return available.first(where: { kind in !recent.contains(where: { $0.kind == kind }) }) ?? .runningCount
    }
}
