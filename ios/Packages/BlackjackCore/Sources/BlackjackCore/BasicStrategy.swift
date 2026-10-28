import Foundation

public struct StrategyOptions: Sendable {
    public var canDouble: Bool?
    public var canSplit: Bool?
    public var canSurrender: Bool?
    public var fromSplit: Bool

    public init(canDouble: Bool? = nil, canSplit: Bool? = nil,
                canSurrender: Bool? = nil, fromSplit: Bool = false) {
        self.canDouble = canDouble
        self.canSplit = canSplit
        self.canSurrender = canSurrender
        self.fromSplit = fromSplit
    }
}

public struct StrategyAdvice: Sendable, Equatable {
    public let move: PlayerMove
    public let reason: String

    public init(move: PlayerMove, reason: String) {
        self.move = move
        self.reason = reason
    }
}

/// Total-dependent basic strategy for 4–8 deck US hole-card games.
/// Count-based deviations, composition-dependent strategy, and no-hole-card games are not included.
public enum BasicStrategy {
    public static func recommend(cards: [Card], dealer: Card, rules: Rules = .standard,
                                 options: StrategyOptions = StrategyOptions()) -> StrategyAdvice {
        let value = HandValue.evaluate(cards)
        let total = value.total
        let up = dealer.value
        let canDouble = (options.canDouble ?? (cards.count == 2)) && (!options.fromSplit || rules.doubleAfterSplit)
        let canSplit = (options.canSplit ?? true) && cards.count == 2 && cards[0].value == cards[1].value
        let canSurrender = (options.canSurrender ?? rules.surrender) && rules.surrender && cards.count == 2 && !options.fromSplit

        if total >= 21 { return StrategyAdvice(move: .stand, reason: "Keep your 21.") }
        if canSplit {
            let pair = cards[0].value
            let split = pair == 11 || pair == 8
                || (pair == 9 && [2, 3, 4, 5, 6, 8, 9].contains(up))
                || (pair == 7 && up <= 7)
                || (pair == 6 && up <= 6 && (up >= 3 || rules.doubleAfterSplit))
                || ([2, 3].contains(pair) && up <= 7 && (up >= 4 || rules.doubleAfterSplit))
                || (pair == 4 && rules.doubleAfterSplit && [5, 6].contains(up))
            if pair == 8 && up == 11 && rules.hitSoft17 && canSurrender {
                return StrategyAdvice(move: .surrender, reason: "Against an ace, H17 makes surrender the better play for eights.")
            }
            if split {
                return StrategyAdvice(move: .split, reason: "Two separate hands are stronger against the dealer’s \(dealer.rank.rawValue).")
            }
        }
        if !value.soft && canSurrender && (
            (total == 16 && [9, 10, 11].contains(up))
                || (total == 15 && (up == 10 || (rules.hitSoft17 && up == 11)))
                || (total == 17 && rules.hitSoft17 && up == 11)
        ) {
            return StrategyAdvice(move: .surrender, reason: "Keep half the stake on this unfavorable hand.")
        }
        if value.soft {
            var double = false
            var fallback: PlayerMove = .hit
            switch total {
            case 20...: fallback = .stand
            case 19:
                double = rules.hitSoft17 && up == 6
                fallback = .stand
            case 18:
                double = up >= (rules.hitSoft17 ? 2 : 3) && up <= 6
                fallback = up <= 8 ? .stand : .hit
            case 17: double = up >= 3 && up <= 6
            case 15, 16: double = up >= 4 && up <= 6
            case 13, 14: double = [5, 6].contains(up)
            default: break
            }
            if double && canDouble {
                return StrategyAdvice(move: .doubleDown, reason: "The flexible ace makes this a favorable double.")
            }
            let verb = fallback == .stand ? "Stand on" : "Hit"
            return StrategyAdvice(move: fallback, reason: "\(verb) soft \(total) against \(dealer.rank.rawValue).")
        }
        let shouldDouble = (total == 9 && up >= 3 && up <= 6)
            || (total == 10 && up <= 9)
            || (total == 11 && (up != 11 || rules.hitSoft17))
        if shouldDouble && canDouble {
            return StrategyAdvice(move: .doubleDown, reason: "\(total) against \(dealer.rank.rawValue) is a favorable double.")
        }
        let stand = total >= 17 || (total >= 13 && up <= 6) || (total == 12 && up >= 4 && up <= 6)
        return StrategyAdvice(move: stand ? .stand : .hit,
                              reason: "\(stand ? "Stand on" : "Hit") hard \(total) against \(dealer.rank.rawValue).")
    }

    /// Advice constrained by the active hand's actual actions and available practice credits.
    public static func recommend(in state: GameState) -> StrategyAdvice? {
        guard state.phase == .playing, let hand = state.currentHand, let dealer = state.dealer.first else { return nil }
        let moves = GameEngine.availableMoves(in: state)
        return recommend(cards: hand.cards, dealer: dealer, rules: state.rules,
                         options: StrategyOptions(canDouble: moves.contains(.doubleDown),
                                                  canSplit: moves.contains(.split),
                                                  canSurrender: moves.contains(.surrender),
                                                  fromSplit: hand.fromSplit))
    }
}
