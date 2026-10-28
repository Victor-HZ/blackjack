import Foundation

private struct TrainingRandom: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

public enum PromptFactory {
    public static func make(kind: DrillKind, seed: UInt64) -> [DrillPrompt] {
        var random = TrainingRandom(state: seed)
        let ranks = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
        var deck = ["♠", "♥", "♦", "♣"].flatMap { suit in ranks.map { TrainingCard(rank: $0, suit: suit) } }
        deck.shuffle(using: &random)
        func signed(_ value: Int) -> String { value > 0 ? "+\(value)" : "\(value)" }
        switch kind {
        case .cardValues:
            return Array(deck.prefix(15)).enumerated().map { index, card in
                DrillPrompt(id: index, kind: kind, cards: [card], expectedAnswer: Double(card.hiLo), cardsSeen: index + 1,
                            explanation: "\(card.rank) is worth \(signed(card.hiLo)) in Hi-Lo.")
            }
        case .pairs:
            return (0..<12).map { index in
                let cards = Array(deck[(index * 2)..<(index * 2 + 2)])
                let sum = cards.reduce(0) { $0 + $1.hiLo }
                return DrillPrompt(id: index, kind: kind, cards: cards, expectedAnswer: Double(sum), cardsSeen: index * 2 + 2,
                                   explanation: "\(signed(cards[0].hiLo)) + (\(signed(cards[1].hiLo))) = \(signed(sum)).")
            }
        case .runningCount, .fullDeck:
            var running = 0
            let count = kind == .runningCount ? 12 : 13
            let group = kind == .runningCount ? 1 : 4
            return (0..<count).map { index in
                let before = running
                let cards = Array(deck[(index * group)..<(index * group + group)])
                let change = cards.reduce(0) { $0 + $1.hiLo }
                running += change
                return DrillPrompt(id: index, kind: kind, cards: cards, expectedAnswer: Double(running), cardsSeen: (index + 1) * group,
                                   explanation: "Previous count \(signed(before)). This group adds \(signed(change)). New count: \(signed(running)).",
                                   previousCount: before)
            }
        case .trueCount:
            return (0..<12).map { index in
                let running = Int.random(in: -18...18, using: &random)
                let decks = Double(Int.random(in: 2...12, using: &random)) / 2
                let result = (Double(running) / decks).rounded(.towardZero)
                let quotient = String(format: "%.2f", Double(running) / decks)
                return DrillPrompt(id: index, kind: kind, expectedAnswer: result, runningCount: running, decksRemaining: decks,
                                   explanation: "\(signed(running)) ÷ \(DrillPrompt.format(decks)) = \(quotient). Drop the decimal toward zero: \(DrillPrompt.format(result, signed: true)).")
            }
        case .deckEstimation:
            var halves = Array(1...12)
            halves.shuffle(using: &random)
            return halves.enumerated().map { index, half in
                let decks = Double(half) / 2
                return DrillPrompt(id: index, kind: kind, expectedAnswer: decks, decksRemaining: decks,
                                   explanation: "The stack is \(DrillPrompt.format(decks)) decks: \(half * 26) cards. One full deck contains 52 cards.")
            }
        }
    }
}
