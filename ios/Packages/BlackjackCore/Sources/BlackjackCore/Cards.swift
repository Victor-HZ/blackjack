import Foundation

public enum Rank: String, CaseIterable, Codable, Sendable, Hashable {
    case ace = "A", two = "2", three = "3", four = "4", five = "5", six = "6"
    case seven = "7", eight = "8", nine = "9", ten = "10", jack = "J", queen = "Q", king = "K"

    public var value: Int {
        switch self {
        case .ace: return 11
        case .jack, .queen, .king: return 10
        default: return Int(rawValue) ?? 0
        }
    }

    public var name: String {
        switch self {
        case .ace: return "Ace"
        case .jack: return "Jack"
        case .queen: return "Queen"
        case .king: return "King"
        default: return rawValue
        }
    }
}

public enum Suit: String, CaseIterable, Codable, Sendable, Hashable {
    case spades, hearts, diamonds, clubs

    public var symbol: String {
        switch self {
        case .spades: return "♠"
        case .hearts: return "♥"
        case .diamonds: return "♦"
        case .clubs: return "♣"
        }
    }

    public var isRed: Bool { self == .hearts || self == .diamonds }
}

public struct Card: Codable, Sendable, Hashable {
    public let rank: Rank
    public let suit: Suit

    public init(rank: Rank, suit: Suit) {
        self.rank = rank
        self.suit = suit
    }

    public var value: Int { rank.value }
    public var hiLoValue: Int {
        switch value {
        case 2...6: return 1
        case 10...11: return -1
        default: return 0
        }
    }
    public var accessibilityLabel: String { "\(rank.name) of \(suit.rawValue)" }
}

public struct HandValue: Equatable, Sendable {
    public let total: Int
    public let soft: Bool
    public let blackjack: Bool
    public let bust: Bool

    public static func evaluate(_ cards: [Card]) -> HandValue {
        var total = cards.reduce(0) { $0 + $1.value }
        var highAces = cards.filter { $0.rank == .ace }.count
        while total > 21 && highAces > 0 {
            total -= 10
            highAces -= 1
        }
        return HandValue(total: total, soft: highAces > 0, blackjack: cards.count == 2 && total == 21, bust: total > 21)
    }
}

/// A reproducible non-cryptographic generator for virtual practice cards.
public struct SeededRandomNumberGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64
    public init(seed: UInt64) { state = seed }

    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

public enum Shoe {
    /// Cards are dealt from the beginning. A seed enables exact regression tests and replay.
    public static func make(decks: Int = 6, seed: UInt64 = UInt64.random(in: 0...UInt64.max)) -> [Card] {
        let deckCount = min(8, max(1, decks))
        var cards = (0..<deckCount).flatMap { _ in
            Suit.allCases.flatMap { suit in Rank.allCases.map { Card(rank: $0, suit: suit) } }
        }
        var generator = SeededRandomNumberGenerator(seed: seed)
        cards.shuffle(using: &generator)
        return cards
    }
}
