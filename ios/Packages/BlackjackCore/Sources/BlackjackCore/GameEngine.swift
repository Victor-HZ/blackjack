import Foundation

/// Pure value-state transitions for virtual, non-redeemable practice credits.
public enum GameEngine {
    public static func availableMoves(in state: GameState) -> [PlayerMove] {
        guard state.phase == .playing, let hand = state.currentHand, hand.status == .playing else { return [] }
        var moves: [PlayerMove] = [.hit, .stand]
        if hand.cards.count == 2 && state.bankrollCents >= hand.betCents
            && (!hand.fromSplit || state.rules.doubleAfterSplit) && !hand.splitAces {
            moves.append(.doubleDown)
        }
        if hand.cards.count == 2 && hand.cards[0].value == hand.cards[1].value
            && state.hands.count < 4 && state.bankrollCents >= hand.betCents && !hand.splitAces {
            moves.append(.split)
        }
        if state.rules.surrender && hand.cards.count == 2 && !hand.fromSplit { moves.append(.surrender) }
        return moves
    }

    public static func reduce(_ previous: GameState, _ action: GameAction) -> GameState {
        guard previous.isValidForRestore else { return previous }
        var state = previous
        switch action {
        case .shuffle:
            guard !state.isRoundActive else { return previous }
            shuffle(&state)
            state.message = "Fresh shoe. Count starts at zero."
            return state
        case .deal(let betCents):
            guard !state.isRoundActive, betCents >= 100, betCents <= state.bankrollCents,
                  betCents <= 1_000_000_000 else { return previous }
            if state.shoe.count <= state.cutCard { shuffle(&state) }
            state.bankrollCents -= betCents
            state.dealer = []
            state.hands = []
            state.activeHand = 0
            state.holeRevealed = false
            state.insuranceBetCents = 0
            state.insurancePayoutCents = 0
            let first = draw(&state)
            let upcard = draw(&state)
            let second = draw(&state)
            let holeCard = draw(&state, visible: false)
            state.dealer = [upcard, holeCard]
            state.hands = [PlayerHand(cards: [first, second], betCents: betCents)]
            if upcard.rank == .ace {
                state.phase = .insurance
                state.message = "Dealer shows an ace. Insurance?"
            } else {
                afterPeek(&state)
            }
            return state
        case .insurance, .declineInsurance:
            guard state.phase == .insurance, let first = state.hands.first else { return previous }
            let cost = roundedRatio(first.betCents, 1, 2)
            if action == .insurance {
                guard state.bankrollCents >= cost else { return previous }
                state.insuranceBetCents = cost
                state.bankrollCents -= cost
            }
            afterPeek(&state)
            return state
        default: break
        }
        guard let move = action.move, availableMoves(in: previous).contains(move) else { return previous }
        let index = state.activeHand
        switch move {
        case .hit:
            let card = draw(&state)
            state.hands[index].cards.append(card)
            let value = state.hands[index].value
            if value.bust || value.total == 21 {
                state.hands[index].status = value.bust ? .bust : .stood
                advance(&state)
            }
        case .stand:
            state.hands[index].status = .stood
            advance(&state)
        case .surrender:
            state.hands[index].status = .surrendered
            advance(&state)
        case .doubleDown:
            state.bankrollCents -= state.hands[index].betCents
            state.hands[index].betCents *= 2
            let card = draw(&state)
            state.hands[index].cards.append(card)
            state.hands[index].status = state.hands[index].value.bust ? .bust : .stood
            advance(&state)
        case .split:
            let original = state.hands[index]
            state.bankrollCents -= original.betCents
            let splitAces = original.cards[0].rank == .ace
            let firstDraw = draw(&state)
            let secondDraw = draw(&state)
            var first = PlayerHand(cards: [original.cards[0], firstDraw], betCents: original.betCents,
                                   fromSplit: true, splitAces: splitAces)
            var second = PlayerHand(cards: [original.cards[1], secondDraw], betCents: original.betCents,
                                    fromSplit: true, splitAces: splitAces)
            if splitAces || first.value.total == 21 { first.status = .stood }
            if splitAces || second.value.total == 21 { second.status = .stood }
            state.hands.replaceSubrange(index...index, with: [first, second])
            if first.status != .playing { advance(&state) }
            else { state.message = "Hand \(state.activeHand + 1) of \(state.hands.count)." }
        }
        return state
    }

    private static func shuffle(_ state: inout GameState) {
        state.seed &+= 1
        state.shoe = Shoe.make(decks: state.rules.decks, seed: state.seed)
        state.cutCard = state.shoe.count / 4
        state.runningCount = 0
    }

    private static func draw(_ state: inout GameState, visible: Bool = true) -> Card {
        // The cut card prevents exhaustion during normal play. Extremely long injected shoes
        // remain safe and deterministic without silently returning a duplicate card.
        if state.shoe.isEmpty { shuffle(&state) }
        let card = state.shoe.removeFirst()
        if visible { state.runningCount += card.hiLoValue }
        return card
    }

    private static func revealHole(_ state: inout GameState) {
        if !state.holeRevealed && state.dealer.count >= 2 {
            state.runningCount += state.dealer[1].hiLoValue
            state.holeRevealed = true
        }
    }

    private static func afterPeek(_ state: inout GameState) {
        if HandValue.evaluate(state.dealer).blackjack || state.hands[0].value.blackjack { settle(&state) }
        else {
            state.phase = .playing
            state.message = "Your move."
        }
    }

    private static func advance(_ state: inout GameState) {
        let following = state.hands.indices.first { $0 > state.activeHand && state.hands[$0].status == .playing }
        if let following {
            state.activeHand = following
            state.message = "Hand \(following + 1) of \(state.hands.count)."
        } else { settle(&state) }
    }

    private static func settle(_ state: inout GameState) {
        revealHole(&state)
        let dealer = HandValue.evaluate(state.dealer)
        let playDealer = !dealer.blackjack && state.hands.contains { hand in
            hand.status != .bust && hand.status != .surrendered && !(hand.value.blackjack && !hand.fromSplit)
        }
        if playDealer {
            while true {
                let value = HandValue.evaluate(state.dealer)
                guard value.total < 17 || (state.rules.hitSoft17 && value.total == 17 && value.soft) else { break }
                let card = draw(&state)
                state.dealer.append(card)
            }
        }
        let finalDealer = HandValue.evaluate(state.dealer)
        for index in state.hands.indices {
            let hand = state.hands[index]
            let player = hand.value
            let outcome: HandOutcome
            let payout: Int
            if hand.status == .surrendered {
                outcome = .surrender
                payout = roundedRatio(hand.betCents, 1, 2)
            } else if player.bust {
                outcome = .loss
                payout = 0
            } else if player.blackjack && !hand.fromSplit {
                outcome = finalDealer.blackjack ? .push : .blackjack
                payout = finalDealer.blackjack ? hand.betCents : (
                    state.rules.blackjackPayout == .threeToTwo
                        ? roundedRatio(hand.betCents, 5, 2)
                        : roundedRatio(hand.betCents, 11, 5)
                )
            } else if finalDealer.blackjack {
                outcome = .loss
                payout = 0
            } else if finalDealer.bust || player.total > finalDealer.total {
                outcome = .win
                payout = hand.betCents * 2
            } else if player.total == finalDealer.total {
                outcome = .push
                payout = hand.betCents
            } else {
                outcome = .loss
                payout = 0
            }
            state.hands[index].outcome = outcome
            state.hands[index].payoutCents = payout
            if state.hands[index].status == .playing { state.hands[index].status = .stood }
            state.bankrollCents += payout
        }
        if state.insuranceBetCents > 0 && finalDealer.blackjack {
            state.insurancePayoutCents = state.insuranceBetCents * 3
            state.bankrollCents += state.insurancePayoutCents
        }
        let bet = state.hands.reduce(state.insuranceBetCents) { $0 + $1.betCents }
        let returned = state.hands.reduce(state.insurancePayoutCents) { $0 + ($1.payoutCents ?? 0) }
        let profit = returned - bet
        state.rounds += 1
        state.history.append(RoundResult(id: state.rounds, betCents: bet, profitCents: profit,
                                         bankrollCents: state.bankrollCents,
                                         outcomes: state.hands.compactMap(\.outcome)))
        state.history = Array(state.history.suffix(500))
        state.phase = .settled
        if profit > 0 { state.message = "+\(formatCredits(profit)) practice credits." }
        else if profit < 0 { state.message = "−\(formatCredits(-profit)) practice credits." }
        else if state.hands.allSatisfy({ $0.outcome == .push }) && state.insuranceBetCents == 0 {
            state.message = "Push. Stake returned."
        } else { state.message = "Round breaks even." }
    }

    private static func roundedRatio(_ amount: Int, _ numerator: Int, _ denominator: Int) -> Int {
        (amount * numerator + denominator / 2) / denominator
    }

    public static func formatCredits(_ cents: Int) -> String {
        if cents % 100 == 0 { return String(cents / 100) }
        return String(format: "%.2f", Double(cents) / 100)
    }
}
