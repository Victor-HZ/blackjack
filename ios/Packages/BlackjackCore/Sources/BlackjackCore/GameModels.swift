import Foundation

public enum BlackjackPayout: String, CaseIterable, Codable, Sendable {
    case threeToTwo = "3:2"
    case sixToFive = "6:5"
}

public struct Rules: Codable, Sendable, Equatable {
    public var decks: Int
    public var hitSoft17: Bool
    public var doubleAfterSplit: Bool
    public var surrender: Bool
    public var blackjackPayout: BlackjackPayout

    public init(decks: Int = 6, hitSoft17: Bool = false, doubleAfterSplit: Bool = true,
                surrender: Bool = true, blackjackPayout: BlackjackPayout = .threeToTwo) {
        self.decks = [4, 6, 8].contains(decks) ? decks : 6
        self.hitSoft17 = hitSoft17
        self.doubleAfterSplit = doubleAfterSplit
        self.surrender = surrender
        self.blackjackPayout = blackjackPayout
    }

    public static let standard = Rules()
    public var isSupported: Bool { [4, 6, 8].contains(decks) }
    public var summary: String { "\(decks) decks · \(hitSoft17 ? "H17" : "S17") · \(blackjackPayout.rawValue)" }
}

public enum GamePhase: String, Codable, Sendable {
    case betting, insurance, playing, settled
}

public enum PlayerMove: String, CaseIterable, Codable, Sendable {
    case hit, stand, doubleDown, split, surrender

    public var title: String {
        switch self {
        case .hit: return "Hit"
        case .stand: return "Stand"
        case .doubleDown: return "Double"
        case .split: return "Split"
        case .surrender: return "Surrender"
        }
    }

    public var symbol: String {
        switch self {
        case .hit: return "plus"
        case .stand: return "hand.raised"
        case .doubleDown: return "arrow.up.right"
        case .split: return "arrow.triangle.branch"
        case .surrender: return "flag"
        }
    }

    public var action: GameAction {
        switch self {
        case .hit: return .hit
        case .stand: return .stand
        case .doubleDown: return .doubleDown
        case .split: return .split
        case .surrender: return .surrender
        }
    }
}

public enum GameAction: Equatable, Sendable {
    case deal(betCents: Int)
    case hit, stand, doubleDown, split, surrender, insurance, declineInsurance, shuffle

    public var move: PlayerMove? {
        switch self {
        case .hit: return .hit
        case .stand: return .stand
        case .doubleDown: return .doubleDown
        case .split: return .split
        case .surrender: return .surrender
        default: return nil
        }
    }
}

public enum HandStatus: String, Codable, Sendable {
    case playing, stood, bust, surrendered
}

public enum HandOutcome: String, Codable, Sendable {
    case win, loss, push, blackjack, surrender

    public var title: String {
        switch self {
        case .win: return "Win"
        case .loss: return "Loss"
        case .push: return "Push"
        case .blackjack: return "Blackjack"
        case .surrender: return "Surrender"
        }
    }
}

public struct PlayerHand: Codable, Sendable, Equatable {
    public var cards: [Card]
    public var betCents: Int
    public var status: HandStatus
    public var fromSplit: Bool
    public var splitAces: Bool
    public var outcome: HandOutcome?
    /// Total returned, including the original stake. Integer cents avoid floating-point drift.
    public var payoutCents: Int?

    public init(cards: [Card], betCents: Int, status: HandStatus = .playing,
                fromSplit: Bool = false, splitAces: Bool = false,
                outcome: HandOutcome? = nil, payoutCents: Int? = nil) {
        self.cards = cards
        self.betCents = betCents
        self.status = status
        self.fromSplit = fromSplit
        self.splitAces = splitAces
        self.outcome = outcome
        self.payoutCents = payoutCents
    }

    public var value: HandValue { HandValue.evaluate(cards) }
    public var bet: Double { Double(betCents) / 100 }
}

public struct RoundResult: Codable, Sendable, Equatable, Identifiable {
    public var id: Int
    public var betCents: Int
    public var profitCents: Int
    public var bankrollCents: Int
    public var outcomes: [HandOutcome]

    public init(id: Int, betCents: Int, profitCents: Int, bankrollCents: Int, outcomes: [HandOutcome]) {
        self.id = id
        self.betCents = betCents
        self.profitCents = profitCents
        self.bankrollCents = bankrollCents
        self.outcomes = outcomes
    }

    public var bet: Double { Double(betCents) / 100 }
    public var profit: Double { Double(profitCents) / 100 }
    public var bankroll: Double { Double(bankrollCents) / 100 }
}

public struct GameState: Codable, Sendable, Equatable {
    public var rules: Rules
    public var phase: GamePhase = .betting
    public var bankrollCents: Int
    public var shoe: [Card]
    public var dealer: [Card] = []
    public var hands: [PlayerHand] = []
    public var activeHand: Int = 0
    public var runningCount: Int = 0
    public var holeRevealed: Bool = false
    public var insuranceBetCents: Int = 0
    public var insurancePayoutCents: Int = 0
    public var rounds: Int = 0
    public var history: [RoundResult] = []
    public var message: String = "Choose your practice stake."
    public var seed: UInt64
    public var cutCard: Int

    public init(bankrollCents: Int = 100_000, rules: Rules = .standard,
                seed: UInt64 = UInt64.random(in: 0...UInt64.max), shoe: [Card]? = nil) {
        self.rules = rules
        self.bankrollCents = max(0, min(bankrollCents, 1_000_000_000_000))
        self.seed = seed
        let cards = shoe ?? Shoe.make(decks: rules.decks, seed: seed)
        self.shoe = cards
        cutCard = cards.count / 4
    }

    public var bankroll: Double { Double(bankrollCents) / 100 }
    public var decksRemaining: Double { Double(shoe.count) / 52 }
    public var trueCount: Double { Double(runningCount) / max(decksRemaining, 0.25) }
    public var isRoundActive: Bool { phase == .playing || phase == .insurance }
    public var currentHand: PlayerHand? { hands.indices.contains(activeHand) ? hands[activeHand] : nil }
    public var visibleDealerCards: [Card] { holeRevealed ? dealer : Array(dealer.prefix(1)) }
    public var dealerValue: HandValue { HandValue.evaluate(visibleDealerCards) }
    public var totalProfitCents: Int { (history.last?.bankrollCents ?? 100_000) - 100_000 }

    /// Reject impossible persisted states before allowing them into the renderer or reducer.
    public var isValidForRestore: Bool {
        guard rules.isSupported, bankrollCents >= 0, bankrollCents <= 1_000_000_000_000,
              shoe.count <= rules.decks * 52, dealer.count <= 32, hands.count <= 4,
              rounds >= 0, rounds <= 1_000_000_000, history.count <= 500, history.count <= rounds,
              runningCount >= -1_000, runningCount <= 1_000, cutCard >= 0, cutCard <= rules.decks * 52,
              insuranceBetCents >= 0, insuranceBetCents <= 1_000_000_000,
              insurancePayoutCents >= 0, insurancePayoutCents <= 3_000_000_000 else { return false }
        guard hands.isEmpty ? activeHand == 0 : hands.indices.contains(activeHand) else { return false }
        guard hands.allSatisfy({ hand in
            (2...32).contains(hand.cards.count) && hand.betCents > 0 && hand.betCents <= 4_000_000_000
                && (hand.payoutCents == nil || (hand.payoutCents! >= 0 && hand.payoutCents! <= 12_000_000_000))
        }) else { return false }
        guard history.allSatisfy({ round in
            round.id > 0 && round.id <= rounds && round.betCents > 0 && round.betCents <= 32_000_000_000
                && round.profitCents >= -32_000_000_000 && round.profitCents <= 32_000_000_000
                && round.bankrollCents >= 0 && round.bankrollCents <= 1_000_000_000_000
                && (1...4).contains(round.outcomes.count)
        }) else { return false }
        switch phase {
        case .betting:
            return hands.isEmpty && dealer.isEmpty && !holeRevealed
        case .insurance:
            return dealer.count == 2 && dealer.first?.rank == .ace && hands.count == 1
                && hands[0].status == .playing && !holeRevealed
                && hands[0].outcome == nil && hands[0].payoutCents == nil
        case .playing:
            return dealer.count == 2 && !hands.isEmpty && hands[activeHand].status == .playing
                && !holeRevealed && hands.allSatisfy { $0.outcome == nil && $0.payoutCents == nil }
        case .settled:
            return dealer.count >= 2 && !hands.isEmpty && holeRevealed && rounds > 0
                && hands.allSatisfy { $0.status != .playing && $0.outcome != nil && $0.payoutCents != nil }
        }
    }
}
