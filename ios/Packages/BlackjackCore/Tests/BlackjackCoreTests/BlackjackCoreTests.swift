import Foundation
import XCTest
@testable import BlackjackCore

final class BlackjackCoreTests: XCTestCase {
    private func cards(_ ranks: Rank...) -> [Card] {
        ranks.map { Card(rank: $0, suit: .spades) }
    }

    /// Keep the prescribed prefix away from the cut card; remaining cards are deterministic.
    private func fresh(_ ranks: [Rank], bankrollCents: Int = 100_000, rules: Rules = .standard) -> GameState {
        let prefix = ranks.map { Card(rank: $0, suit: .spades) }
        let tail = Array(repeating: Card(rank: .ten, suit: .clubs), count: 208)
        return GameState(bankrollCents: bankrollCents, rules: rules, seed: 42, shoe: prefix + tail)
    }

    private func deal(_ ranks: [Rank], betCents: Int = 10_000, bankrollCents: Int = 100_000, rules: Rules = .standard) -> GameState {
        GameEngine.reduce(fresh(ranks, bankrollCents: bankrollCents, rules: rules), .deal(betCents: betCents))
    }

    func testMultipleAcesProduceSoftTwentyOne() {
        let score = HandValue.evaluate(cards(.ace, .ace, .nine))
        XCTAssertEqual(score.total, 21)
        XCTAssertTrue(score.soft)
        XCTAssertFalse(score.blackjack)
        XCTAssertFalse(score.bust)
    }

    func testSoftAceBecomesHardAfterAHit() {
        let score = HandValue.evaluate(cards(.ace, .six, .ten))
        XCTAssertEqual(score.total, 17)
        XCTAssertFalse(score.soft)
        XCTAssertFalse(score.bust)
    }

    func testNaturalAndBustAreDistinct() {
        XCTAssertTrue(HandValue.evaluate(cards(.ace, .queen)).blackjack)
        XCTAssertTrue(HandValue.evaluate(cards(.king, .queen, .two)).bust)
        XCTAssertFalse(HandValue.evaluate(cards(.seven, .seven, .seven)).blackjack)
    }

    func testHiLoCardValues() {
        for rank in [Rank.two, .three, .four, .five, .six] {
            XCTAssertEqual(Card(rank: rank, suit: .hearts).hiLoValue, 1)
        }
        for rank in [Rank.seven, .eight, .nine] {
            XCTAssertEqual(Card(rank: rank, suit: .diamonds).hiLoValue, 0)
        }
        for rank in [Rank.ten, .jack, .queen, .king, .ace] {
            XCTAssertEqual(Card(rank: rank, suit: .clubs).hiLoValue, -1)
        }
    }

    func testSeededShoeContainsSixCompleteBalancedDecks() {
        let first = GameState(seed: 123)
        let second = GameState(seed: 123)
        let other = GameState(seed: 124)
        XCTAssertEqual(first.shoe.count, 312)
        XCTAssertEqual(first.shoe, second.shoe)
        XCTAssertNotEqual(first.shoe, other.shoe)
        XCTAssertEqual(first.shoe.filter { $0.rank == .ace && $0.suit == .hearts }.count, 6)
        XCTAssertEqual(first.shoe.reduce(0) { $0 + $1.hiLoValue }, 0)
    }

    func testTrueCountUsesUndealtDecks() {
        var state = GameState(seed: 123)
        state.shoe = Array(repeating: Card(rank: .ten, suit: .spades), count: 104)
        state.runningCount = 8
        XCTAssertEqual(state.decksRemaining, 2, accuracy: 0.0001)
        XCTAssertEqual(state.trueCount, 4, accuracy: 0.0001)
    }

    func testHoleCardDoesNotEnterCountUntilRevealed() {
        let initial = deal([.ten, .six, .seven, .ten, .ten])
        XCTAssertEqual(initial.phase, .playing)
        XCTAssertFalse(initial.holeRevealed)
        XCTAssertEqual(initial.runningCount, 0)
        let settled = GameEngine.reduce(initial, .stand)
        XCTAssertTrue(settled.holeRevealed)
        XCTAssertEqual(settled.runningCount, -2)
        XCTAssertEqual(settled.bankrollCents, 110_000)
        XCTAssertEqual(initial.bankrollCents, 90_000)
        XCTAssertEqual(initial.dealer.count, 2)
    }

    func testNaturalPaysThreeToTwo() {
        let state = deal([.ace, .ten, .king, .queen])
        XCTAssertEqual(state.phase, .settled)
        XCTAssertEqual(state.hands[0].outcome, .blackjack)
        XCTAssertEqual(state.hands[0].payoutCents, 25_000)
        XCTAssertEqual(state.bankrollCents, 115_000)
        XCTAssertEqual(state.history[0].profitCents, 15_000)
    }

    func testNaturalPaysSixToFiveWhenSelected() {
        let state = deal([.ace, .ten, .king, .queen], rules: Rules(blackjackPayout: .sixToFive))
        XCTAssertEqual(state.hands[0].outcome, .blackjack)
        XCTAssertEqual(state.hands[0].payoutCents, 22_000)
        XCTAssertEqual(state.bankrollCents, 112_000)
    }

    func testEqualTotalsPushAndReturnStake() {
        let state = GameEngine.reduce(deal([.ten, .ten, .eight, .eight]), .stand)
        XCTAssertEqual(state.hands[0].outcome, .push)
        XCTAssertEqual(state.bankrollCents, 100_000)
        XCTAssertEqual(state.history[0].profitCents, 0)
    }

    func testPlayerAndDealerNaturalsPush() {
        let offered = deal([.ace, .ace, .king, .queen])
        XCTAssertEqual(offered.phase, .insurance)
        let state = GameEngine.reduce(offered, .declineInsurance)
        XCTAssertEqual(state.hands[0].outcome, .push)
        XCTAssertEqual(state.bankrollCents, 100_000)
    }

    func testDealerNaturalBeatsAnOrdinaryHandImmediatelyAfterPeek() {
        let state = deal([.ten, .ten, .nine, .ace])
        XCTAssertEqual(state.phase, .settled)
        XCTAssertEqual(state.hands[0].outcome, .loss)
        XCTAssertEqual(state.bankrollCents, 90_000)
        XCTAssertTrue(state.holeRevealed)
    }

    func testBustDoesNotDrawUnnecessaryDealerCards() {
        let state = GameEngine.reduce(deal([.ten, .six, .seven, .five, .king]), .hit)
        XCTAssertEqual(state.hands[0].status, .bust)
        XCTAssertEqual(state.hands[0].outcome, .loss)
        XCTAssertEqual(state.dealer.count, 2)
        XCTAssertEqual(state.bankrollCents, 90_000)
        XCTAssertEqual(state.history[0].profitCents, -10_000)
    }

    func testDoubleDrawsExactlyOneCardAndDoublesStake() {
        let state = GameEngine.reduce(deal([.five, .six, .six, .ten, .ten, .ten]), .doubleDown)
        XCTAssertEqual(state.phase, .settled)
        XCTAssertEqual(state.hands[0].cards.count, 3)
        XCTAssertEqual(state.hands[0].betCents, 20_000)
        XCTAssertEqual(state.history[0].betCents, 20_000)
        XCTAssertEqual(state.bankrollCents, 120_000)
    }

    func testSplitAcesReceiveOneCardAndTwentyOnePaysAnOrdinaryWin() {
        let state = GameEngine.reduce(deal([.ace, .ten, .ace, .seven, .king, .nine]), .split)
        XCTAssertEqual(state.phase, .settled)
        XCTAssertEqual(state.hands.count, 2)
        XCTAssertEqual(state.hands.map(\.cards.count), [2, 2])
        XCTAssertEqual(state.hands.map(\.outcome), [.win, .win])
        XCTAssertEqual(state.bankrollCents, 120_000)
        XCTAssertTrue(GameEngine.availableMoves(in: state).isEmpty)
    }

    func testSplitAcesCannotBeResplit() {
        let state = GameEngine.reduce(deal([.ace, .ten, .ace, .seven, .ace, .ace]), .split)
        XCTAssertEqual(state.phase, .settled)
        XCTAssertEqual(state.hands.count, 2)
        XCTAssertEqual(state.hands.map(\.cards.count), [2, 2])
        let attempted = GameEngine.reduce(state, .split)
        XCTAssertEqual(attempted.hands.count, 2)
        XCTAssertEqual(attempted.bankrollCents, state.bankrollCents)
    }

    func testSplitHandsAdvanceInOrderAndDisallowDoubleAfterSplitWhenConfigured() {
        var state = GameEngine.reduce(deal([.eight, .ten, .eight, .seven, .three, .two, .ten, .nine], rules: Rules(doubleAfterSplit: false)), .split)
        XCTAssertEqual(state.activeHand, 0)
        XCTAssertFalse(GameEngine.availableMoves(in: state).contains(.doubleDown))
        XCTAssertFalse(GameEngine.availableMoves(in: state).contains(.surrender))
        state = GameEngine.reduce(state, .hit)
        XCTAssertEqual(state.activeHand, 1)
        XCTAssertEqual(state.phase, .playing)
        state = GameEngine.reduce(state, .hit)
        state = GameEngine.reduce(state, .stand)
        XCTAssertEqual(state.phase, .settled)
        XCTAssertEqual(state.bankrollCents, 120_000)
    }

    func testDoubleAfterSplitWhenAllowedUsesSeparateStakes() {
        var state = GameEngine.reduce(deal([.eight, .six, .eight, .ten, .three, .two, .ten, .ten, .ten]), .split)
        XCTAssertTrue(GameEngine.availableMoves(in: state).contains(.doubleDown))
        state = GameEngine.reduce(state, .doubleDown)
        XCTAssertEqual(state.activeHand, 1)
        state = GameEngine.reduce(state, .doubleDown)
        XCTAssertEqual(state.hands.map(\.betCents), [20_000, 20_000])
        XCTAssertEqual(state.history[0].betCents, 40_000)
        XCTAssertEqual(state.bankrollCents, 140_000)
    }

    func testLateSurrenderReturnsHalfTheStake() {
        let state = GameEngine.reduce(deal([.ten, .ten, .six, .seven]), .surrender)
        XCTAssertEqual(state.hands[0].outcome, .surrender)
        XCTAssertEqual(state.hands[0].payoutCents, 5_000)
        XCTAssertEqual(state.bankrollCents, 95_000)
        XCTAssertEqual(state.history[0].profitCents, -5_000)
    }

    func testFractionalCreditSurrenderUsesRoundedIntegerCentsConsistently() {
        for bet in [107, 113, 115, 2_551] {
            let state = GameEngine.reduce(deal([.ten, .ten, .six, .seven], betCents: bet), .surrender)
            let returned = (bet + 1) / 2
            XCTAssertEqual(state.hands[0].payoutCents, returned)
            XCTAssertEqual(state.bankrollCents, 100_000 - bet + returned)
            XCTAssertEqual(state.history[0].profitCents, state.bankrollCents - 100_000)
        }
    }

    func testSurrenderCannotBeTakenAfterAHitOrWhenDisabled() {
        let hit = GameEngine.reduce(deal([.five, .ten, .six, .seven, .two]), .hit)
        XCTAssertFalse(GameEngine.availableMoves(in: hit).contains(.surrender))
        XCTAssertFalse(GameEngine.availableMoves(in: hit).contains(.doubleDown))
        let disabled = deal([.ten, .ten, .six, .seven], rules: Rules(surrender: false))
        XCTAssertFalse(GameEngine.availableMoves(in: disabled).contains(.surrender))
        XCTAssertEqual(GameEngine.reduce(disabled, .surrender).phase, .playing)
    }

    func testInsuranceIsOfferedBeforeDealerNaturalIsRevealedAndPaysTwoToOne() {
        let offered = deal([.nine, .ace, .eight, .king])
        XCTAssertEqual(offered.phase, .insurance)
        XCTAssertFalse(offered.holeRevealed)
        let insured = GameEngine.reduce(offered, .insurance)
        XCTAssertEqual(insured.bankrollCents, 100_000)
        XCTAssertEqual(insured.history[0].betCents, 15_000)
        XCTAssertEqual(insured.history[0].profitCents, 0)
        XCTAssertEqual(insured.hands[0].outcome, .loss)
        XCTAssertEqual(GameEngine.reduce(offered, .declineInsurance).bankrollCents, 90_000)
    }

    func testInsuranceLossIsIncludedInNetResult() {
        var state = GameEngine.reduce(deal([.ten, .ace, .nine, .six]), .insurance)
        XCTAssertEqual(state.phase, .playing)
        state = GameEngine.reduce(state, .stand)
        XCTAssertEqual(state.bankrollCents, 105_000)
        XCTAssertEqual(state.history[0].profitCents, 5_000)
        XCTAssertEqual(state.history[0].betCents, 15_000)
    }

    func testInsufficientBankrollCannotBuyInsurance() {
        let state = deal([.nine, .ace, .eight, .king], bankrollCents: 10_000)
        let attempted = GameEngine.reduce(state, .insurance)
        XCTAssertEqual(attempted.phase, .insurance)
        XCTAssertEqual(attempted.bankrollCents, 0)
        XCTAssertFalse(attempted.holeRevealed)
        XCTAssertEqual(GameEngine.reduce(attempted, .declineInsurance).phase, .settled)
    }

    func testSoftSeventeenRuleChangesDealerDraw() {
        let prefix: [Rank] = [.ten, .ace, .eight, .six, .four]
        let s17 = GameEngine.reduce(GameEngine.reduce(deal(prefix), .declineInsurance), .stand)
        let h17 = GameEngine.reduce(GameEngine.reduce(deal(prefix, rules: Rules(hitSoft17: true)), .declineInsurance), .stand)
        XCTAssertEqual(s17.dealer.count, 2)
        XCTAssertEqual(s17.bankrollCents, 110_000)
        XCTAssertEqual(h17.dealer.count, 3)
        XCTAssertEqual(h17.bankrollCents, 90_000)
    }

    func testInvalidBetsAndOutOfPhaseActionsLeaveGameUntouched() {
        let state = fresh([.five, .six, .six, .ten], bankrollCents: 10_000)
        for action in [GameAction.deal(betCents: 0), .deal(betCents: -1), .deal(betCents: 10_001), .hit, .doubleDown, .insurance] {
            let next = GameEngine.reduce(state, action)
            XCTAssertEqual(next.phase, .betting)
            XCTAssertEqual(next.bankrollCents, 10_000)
            XCTAssertEqual(next.shoe, state.shoe)
        }
    }

    func testAdditionalStakeRequiresAvailableBankroll() {
        let state = deal([.five, .six, .five, .ten], bankrollCents: 10_000)
        XCTAssertEqual(state.bankrollCents, 0)
        XCTAssertFalse(GameEngine.availableMoves(in: state).contains(.doubleDown))
        XCTAssertFalse(GameEngine.availableMoves(in: state).contains(.split))
        XCTAssertEqual(GameEngine.reduce(state, .doubleDown).hands[0].betCents, 10_000)
        XCTAssertEqual(GameEngine.reduce(state, .shuffle).shoe, state.shoe)
        XCTAssertEqual(GameEngine.reduce(state, .deal(betCents: 100)).shoe, state.shoe)
    }

    func testCompletedHandCannotBeSettledTwice() {
        let completed = GameEngine.reduce(deal([.ten, .six, .eight, .ten, .ten]), .stand)
        for action in [GameAction.stand, .hit, .surrender, .doubleDown, .insurance, .declineInsurance] {
            let next = GameEngine.reduce(completed, action)
            XCTAssertEqual(next.bankrollCents, completed.bankrollCents)
            XCTAssertEqual(next.history.count, 1)
            XCTAssertEqual(next.rounds, 1)
        }
    }

    func testReducerIsDeterministicAndDoesNotMutateInput() {
        let state = deal([.five, .six, .six, .ten, .ten, .ten])
        let first = GameEngine.reduce(state, .doubleDown)
        let second = GameEngine.reduce(state, .doubleDown)
        XCTAssertEqual(first.bankrollCents, second.bankrollCents)
        XCTAssertEqual(first.shoe, second.shoe)
        XCTAssertEqual(first.dealer, second.dealer)
        XCTAssertEqual(state.hands[0].cards.count, 2)
        XCTAssertEqual(state.bankrollCents, 90_000)
    }

    func testGameStateRoundTripsThroughCodable() throws {
        let state = GameEngine.reduce(deal([.eight, .ten, .eight, .seven, .three, .two]), .split)
        let encoded = try JSONEncoder().encode(state)
        let restored = try JSONDecoder().decode(GameState.self, from: encoded)
        XCTAssertEqual(restored.phase, state.phase)
        XCTAssertEqual(restored.bankrollCents, state.bankrollCents)
        XCTAssertEqual(restored.shoe, state.shoe)
        XCTAssertEqual(restored.hands.count, state.hands.count)
        XCTAssertEqual(restored.activeHand, state.activeHand)
        XCTAssertEqual(GameEngine.reduce(restored, .stand).bankrollCents, GameEngine.reduce(state, .stand).bankrollCents)
    }

    func testBasicStrategyForRepresentativePairsHardAndSoftTotals() {
        let examples: [([Rank], Rank, PlayerMove)] = [
            ([.eight, .eight], .ten, .split),
            ([.ace, .ace], .ace, .split),
            ([.ten, .ten], .six, .stand),
            ([.five, .five], .six, .doubleDown),
            ([.ten, .six], .ten, .surrender),
            ([.ten, .two], .three, .hit),
            ([.ten, .two], .four, .stand),
            ([.ace, .seven], .nine, .hit),
            ([.ace, .seven], .six, .doubleDown),
            ([.ace, .eight], .six, .stand),
            ([.five, .six], .ace, .hit),
            ([.nine, .nine], .seven, .stand)
        ]
        for (ranks, upcard, expected) in examples {
            let advice = BasicStrategy.recommend(cards: ranks.map { Card(rank: $0, suit: .spades) }, dealer: Card(rank: upcard, suit: .diamonds))
            XCTAssertEqual(advice.move, expected)
            XCTAssertFalse(advice.reason.isEmpty)
        }
    }

    func testBasicStrategyAccountsForSoftSeventeenExceptions() {
        let rules = Rules(hitSoft17: true)
        XCTAssertEqual(BasicStrategy.recommend(cards: cards(.ace, .eight), dealer: Card(rank: .six, suit: .clubs), rules: rules).move, .doubleDown)
        XCTAssertEqual(BasicStrategy.recommend(cards: cards(.five, .six), dealer: Card(rank: .ace, suit: .clubs), rules: rules).move, .doubleDown)
        XCTAssertEqual(BasicStrategy.recommend(cards: cards(.ten, .seven), dealer: Card(rank: .ace, suit: .clubs), rules: rules).move, .surrender)
        XCTAssertEqual(BasicStrategy.recommend(cards: cards(.eight, .eight), dealer: Card(rank: .ace, suit: .clubs), rules: rules).move, .surrender)
    }

    func testStrategyFallsBackWhenDoubleSplitOrSurrenderUnavailable() {
        XCTAssertEqual(BasicStrategy.recommend(cards: cards(.ace, .seven), dealer: Card(rank: .six, suit: .clubs), options: StrategyOptions(canDouble: false)).move, .stand)
        XCTAssertEqual(BasicStrategy.recommend(cards: cards(.five, .six), dealer: Card(rank: .six, suit: .clubs), options: StrategyOptions(canDouble: false)).move, .hit)
        XCTAssertEqual(BasicStrategy.recommend(cards: cards(.eight, .eight), dealer: Card(rank: .ten, suit: .clubs), options: StrategyOptions(canSplit: false, canSurrender: false)).move, .hit)
        XCTAssertEqual(BasicStrategy.recommend(cards: cards(.ten, .six), dealer: Card(rank: .ten, suit: .clubs), rules: Rules(surrender: false)).move, .hit)
        XCTAssertEqual(BasicStrategy.recommend(cards: cards(.two, .two), dealer: Card(rank: .two, suit: .clubs), rules: Rules(doubleAfterSplit: false)).move, .hit)
    }
    func testFourHandSplitCapPreventsAHiddenExtraStake() {
        let prefix: [Rank] = [.eight, .six, .eight, .ten, .eight, .eight, .eight, .eight, .eight, .eight]
        var state = deal(prefix)
        for expectedCount in 2...4 {
            XCTAssertTrue(GameEngine.availableMoves(in: state).contains(.split))
            state = GameEngine.reduce(state, .split)
            XCTAssertEqual(state.hands.count, expectedCount)
        }
        XCTAssertEqual(state.bankrollCents, 60_000)
        XCTAssertFalse(GameEngine.availableMoves(in: state).contains(.split))
        let denied = GameEngine.reduce(state, .split)
        XCTAssertEqual(denied.hands.count, 4)
        XCTAssertEqual(denied.bankrollCents, 60_000)
        XCTAssertEqual(denied.shoe, state.shoe)
    }

    func testRestoreValidationAcceptsRealGameTransitions() {
        let initial = fresh([.eight, .six, .eight, .ten, .three, .two, .ten, .ten, .ten])
        let active = GameEngine.reduce(initial, .deal(betCents: 10_000))
        let split = GameEngine.reduce(active, .split)
        let secondHand = GameEngine.reduce(split, .doubleDown)
        let settled = GameEngine.reduce(secondHand, .doubleDown)
        let reshuffled = GameEngine.reduce(settled, .shuffle)
        for state in [initial, active, split, secondHand, settled, reshuffled] {
            XCTAssertTrue(state.isValidForRestore)
        }
        XCTAssertEqual(reshuffled.runningCount, 0)
        XCTAssertEqual(reshuffled.history, settled.history)
        XCTAssertEqual(reshuffled.bankrollCents, settled.bankrollCents)
        XCTAssertTrue(deal([.nine, .ace, .eight, .king]).isValidForRestore)
        XCTAssertTrue(GameEngine.reduce(deal([.ten, .ten, .six, .seven]), .surrender).isValidForRestore)
    }

    func testRestoreValidationRejectsExtremeCountsWithoutOverflow() {
        for invalid in [Int.min, Int.max, -1_001, 1_001] {
            var state = GameState(seed: 1)
            state.runningCount = invalid
            XCTAssertFalse(state.isValidForRestore)
            XCTAssertEqual(GameEngine.reduce(state, .deal(betCents: 1_000)), state)
        }
    }

    func testRestoreValidationRejectsUnsafeInsuranceAmounts() {
        var insurance = deal([.nine, .ace, .eight, .king])
        insurance.insuranceBetCents = Int.max
        XCTAssertFalse(insurance.isValidForRestore)
        var payout = GameState(seed: 1)
        payout.insurancePayoutCents = Int.max
        XCTAssertFalse(payout.isValidForRestore)
    }

    func testRestoreValidationRejectsInvalidActiveIndexAndMissingDealer() {
        var index = deal([.ten, .six, .eight, .ten])
        index.activeHand = Int.max
        XCTAssertFalse(index.isValidForRestore)
        var negativeIndex = deal([.ten, .six, .eight, .ten])
        negativeIndex.activeHand = -1
        XCTAssertFalse(negativeIndex.isValidForRestore)
        var missingDealer = deal([.ten, .six, .eight, .ten])
        missingDealer.dealer = []
        XCTAssertFalse(missingDealer.isValidForRestore)
        var missingHand = deal([.ten, .six, .eight, .ten])
        missingHand.hands = []
        XCTAssertFalse(missingHand.isValidForRestore)
    }

    func testRestoreValidationRejectsImpossiblePhaseAndHandResults() {
        var emptyActive = GameState(seed: 1)
        emptyActive.phase = .playing
        XCTAssertFalse(emptyActive.isValidForRestore)
        var emptySettled = GameState(seed: 1)
        emptySettled.phase = .settled
        XCTAssertFalse(emptySettled.isValidForRestore)
        var prematurePayout = deal([.ten, .six, .eight, .ten])
        prematurePayout.hands[0].payoutCents = 20_000
        XCTAssertFalse(prematurePayout.isValidForRestore)
        var wrongInsurance = deal([.ten, .six, .eight, .ten])
        wrongInsurance.phase = .insurance
        XCTAssertFalse(wrongInsurance.isValidForRestore)
        var exposedHole = deal([.ten, .six, .eight, .ten])
        exposedHole.holeRevealed = true
        XCTAssertFalse(exposedHole.isValidForRestore)
    }
    func testSeededMultiRoundPlayMaintainsLedgerAcrossRulesAndReshuffles() throws {
        let variants: [Rules] = [
            .standard,
            Rules(decks: 4, hitSoft17: true),
            Rules(decks: 8, doubleAfterSplit: false),
            Rules(decks: 6, surrender: false),
            Rules(decks: 4, blackjackPayout: .sixToFive),
            Rules(decks: 8, hitSoft17: true, doubleAfterSplit: false, surrender: false, blackjackPayout: .sixToFive)
        ]
        for (variant, rules) in variants.enumerated() {
            let startingSeed = UInt64(12_340 + variant)
            let startingBankroll = 10_000_000
            var state = GameState(bankrollCents: startingBankroll, rules: rules, seed: startingSeed)
            for round in 1...100 {
                let before = state.bankrollCents
                state = GameEngine.reduce(state, .deal(betCents: 2_500))
                XCTAssertTrue(state.isValidForRestore, "Variant \(variant), round \(round), after deal")
                if state.phase == .insurance {
                    state = GameEngine.reduce(state, .declineInsurance)
                    XCTAssertTrue(state.isValidForRestore, "Insurance decision must remain resumable")
                }
                var moves = 0
                while state.phase == .playing && moves < 40 {
                    let advice = try XCTUnwrap(BasicStrategy.recommend(in: state))
                    XCTAssertTrue(GameEngine.availableMoves(in: state).contains(advice.move))
                    state = GameEngine.reduce(state, advice.move.action)
                    XCTAssertTrue(state.isValidForRestore, "Variant \(variant), round \(round), move \(moves)")
                    moves += 1
                }
                guard state.phase == .settled else {
                    XCTFail("Variant \(variant), round \(round) did not settle within 40 moves")
                    return
                }
                let result = try XCTUnwrap(state.history.last)
                XCTAssertEqual(result.profitCents, state.bankrollCents - before)
                XCTAssertEqual(result.bankrollCents, state.bankrollCents)
                XCTAssertEqual(result.id, round)
                XCTAssertEqual(state.rounds, round)
                XCTAssertGreaterThanOrEqual(state.bankrollCents, 0)
            }
            XCTAssertEqual(state.history.count, 100)
            XCTAssertEqual(state.bankrollCents - startingBankroll, state.history.reduce(0) { $0 + $1.profitCents })
            XCTAssertGreaterThan(state.seed, startingSeed, "100 rounds must exercise an automatic cut-card reshuffle")
        }
    }
}
