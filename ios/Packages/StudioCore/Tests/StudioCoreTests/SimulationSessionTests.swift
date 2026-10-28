import Foundation
import XCTest
import BlackjackCore
import TrainingCore
@testable import StudioCore

final class SimulationSessionTests: XCTestCase {
    private func shoe(_ ranks: Rank...) -> [Card] {
        ranks.map { Card(rank: $0, suit: .spades) }
            + Array(repeating: Card(rank: .ten, suit: .clubs), count: 200)
    }

    /// Exercise the public transition API, including feedback/count gates, until completion.
    private func complete(_ session: inout SimulationSession, correctStrategy: Bool = true,
                          countOffset: Int = 0, file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<10_000 {
            guard session.isValidForRestore else {
                XCTFail("Invalid state at \(session.stage)", file: file, line: line)
                return
            }
            let advanced: Bool
            switch session.stage {
            case .ready:
                advanced = session.startNextRound()
            case .playing:
                let action: GameAction
                if session.game.phase == .insurance { action = .declineInsurance }
                else if correctStrategy, let advice = BasicStrategy.recommend(in: session.game) { action = advice.move.action }
                else { action = .stand }
                advanced = session.play(action)
            case .decisionFeedback:
                advanced = session.continueDecisionFeedback()
            case .roundReview:
                advanced = session.configuration.countChecks ? session.beginCountCheck() : session.finishRound()
            case .countCheck:
                advanced = session.submitCount(session.game.runningCount + countOffset)
            case .countFeedback:
                advanced = session.finishRound()
            case .complete:
                return
            }
            guard advanced else {
                XCTFail("Expected transition was rejected at \(session.stage)", file: file, line: line)
                return
            }
        }
        XCTFail("Simulation did not reach its selected round limit", file: file, line: line)
    }

    private func altered<T: Codable>(_ value: T, _ change: (inout [String: Any]) -> Void) throws -> T {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any])
        change(&object)
        return try JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: object))
    }

    func testOnlySupportedRoundCountsAreAcceptedByConfiguration() {
        for rounds in [10, 25, 50] {
            XCTAssertEqual(SimulationConfiguration(rounds: rounds).rounds, rounds)
        }
        for rounds in [Int.min, -1, 0, 1, 24, 51, Int.max] {
            XCTAssertEqual(SimulationConfiguration(rounds: rounds).rounds, 10)
        }
    }

    func testEachRoundLimitStopsExactlyOnceAndCannotDealAgain() throws {
        for rounds in [10, 25, 50] {
            var session = SimulationSession(configuration: .init(rounds: rounds, mode: .test, countChecks: true), seed: UInt64(rounds))
            XCTAssertNil(session.summary())
            complete(&session)
            XCTAssertEqual(session.stage, .complete)
            XCTAssertEqual(session.completedRounds, rounds)
            XCTAssertEqual(session.game.rounds, rounds)
            XCTAssertEqual(session.countResponses.count, rounds)
            XCTAssertGreaterThanOrEqual(session.game.bankrollCents, 100)
            let summary = try XCTUnwrap(session.summary())
            XCTAssertEqual(summary.completedRounds, rounds)
            XCTAssertEqual(summary.strategyAccuracy, 1)
            XCTAssertEqual(summary.countAccuracy, 1)
            XCTAssertTrue(summary.isValidForRestore)
            let game = session.game
            let scored = session.decisions.count
            XCTAssertFalse(session.startNextRound())
            XCTAssertFalse(session.finishRound())
            XCTAssertFalse(session.play(.stand))
            XCTAssertFalse(session.submitCount(0))
            XCTAssertEqual(session.game, game)
            XCTAssertEqual(session.decisions.count, scored)
            XCTAssertEqual(session.summary()?.id, summary.id)
        }
    }

    func testNaturalIsOneRoundWithNoFabricatedStrategyAnswer() throws {
        var session = SimulationSession(configuration: .init(mode: .test, countChecks: false), seed: 10,
                                        shoe: shoe(.ace, .ten, .king, .queen))
        XCTAssertTrue(session.startNextRound())
        XCTAssertEqual(session.stage, .roundReview)
        XCTAssertEqual(session.game.hands.first?.outcome, .blackjack)
        XCTAssertEqual(session.game.rounds, 1)
        XCTAssertEqual(session.completedRounds, 0)
        XCTAssertTrue(session.decisions.isEmpty)
        XCTAssertFalse(session.startNextRound())
        XCTAssertTrue(session.finishRound())
        XCTAssertEqual(session.completedRounds, 1)
        XCTAssertEqual(session.stage, .ready)
    }

    func testAllNaturalRoundsDoNotInventAnAccuracyScore() throws {
        let ranks: [Rank] = (0..<10).flatMap { _ in [Rank.ace, .ten, .king, .queen] }
        let cards = ranks.map { Card(rank: $0, suit: .spades) }
            + Array(repeating: Card(rank: .ten, suit: .clubs), count: 200)
        var session = SimulationSession(configuration: .init(mode: .test, countChecks: false), seed: 10, shoe: cards)
        complete(&session)
        let summary = try XCTUnwrap(session.summary())
        XCTAssertEqual(summary.completedRounds, 10)
        XCTAssertTrue(summary.decisions.isEmpty)
        XCTAssertNil(summary.strategyAccuracy)
        XCTAssertNil(summary.countAccuracy)
        XCTAssertTrue(summary.isValidForRestore)
    }

    func testSplitHandsRemainOneRoundAndUseTheirActualDecisionContext() throws {
        var session = SimulationSession(configuration: .init(mode: .test, countChecks: false), seed: 4,
                                        shoe: shoe(.eight, .six, .eight, .ten, .three, .two, .ten, .ten, .ten))
        XCTAssertTrue(session.startNextRound())
        XCTAssertTrue(session.play(.split))
        let split = try XCTUnwrap(session.decisions.first)
        XCTAssertEqual(split.topic, .pairs)
        XCTAssertEqual(split.cards.map(\.rank), [.eight, .eight])
        XCTAssertEqual(split.dealer.rank, .six)
        XCTAssertEqual(split.chosen, .split)
        XCTAssertEqual(split.recommended, .split)
        XCTAssertTrue(split.correct)
        XCTAssertTrue(session.play(.doubleDown))
        let doubled = try XCTUnwrap(session.decisions.last)
        XCTAssertEqual(doubled.cards.map(\.rank), [.eight, .three])
        XCTAssertTrue(doubled.fromSplit)
        XCTAssertEqual(doubled.round, 1)
        XCTAssertTrue(session.play(.doubleDown))
        XCTAssertEqual(session.game.hands.count, 2)
        XCTAssertEqual(session.game.rounds, 1)
        XCTAssertEqual(session.completedRounds, 0)
        XCTAssertTrue(session.finishRound())
        XCTAssertEqual(session.completedRounds, 1)
        XCTAssertEqual(session.decisions.count, 3)
        XCTAssertTrue(session.decisions.allSatisfy { $0.round == 1 })
    }

    func testGuidedModeRequiresFeedbackAcknowledgementBeforeFurtherPlay() {
        var session = SimulationSession(configuration: .init(mode: .guided, countChecks: false), seed: 1,
                                        shoe: shoe(.five, .six, .three, .ten, .two, .ten))
        XCTAssertTrue(session.startNextRound())
        XCTAssertTrue(session.play(.hit))
        XCTAssertEqual(session.stage, .decisionFeedback)
        XCTAssertEqual(session.game.phase, .playing)
        let game = session.game
        XCTAssertFalse(session.play(.stand))
        XCTAssertFalse(session.finishRound())
        XCTAssertFalse(session.startNextRound())
        XCTAssertEqual(session.game, game)
        XCTAssertEqual(session.decisions.count, 1)
        XCTAssertTrue(session.continueDecisionFeedback())
        XCTAssertEqual(session.stage, .playing)
        XCTAssertFalse(session.continueDecisionFeedback())
        XCTAssertTrue(session.play(.stand))
        XCTAssertEqual(session.stage, .decisionFeedback)
        XCTAssertEqual(session.game.phase, .settled)
        XCTAssertFalse(session.finishRound())
        XCTAssertTrue(session.continueDecisionFeedback())
        XCTAssertEqual(session.stage, .roundReview)
        XCTAssertTrue(session.finishRound())
        XCTAssertEqual(session.completedRounds, 1)
    }

    func testTestModeContinuesWithoutImmediateFeedbackAndKeepsMistakes() throws {
        var session = SimulationSession(configuration: .init(mode: .test, countChecks: false), seed: 1,
                                        shoe: shoe(.five, .six, .three, .ten, .ten))
        XCTAssertTrue(session.startNextRound())
        XCTAssertTrue(session.play(.stand))
        XCTAssertEqual(session.stage, .roundReview)
        let decision = try XCTUnwrap(session.decisions.first)
        XCTAssertEqual(decision.chosen, .stand)
        XCTAssertEqual(decision.recommended, .hit)
        XCTAssertFalse(decision.correct)
        XCTAssertFalse(decision.explanation.isEmpty)
        complete(&session)
        let summary = try XCTUnwrap(session.summary())
        XCTAssertEqual(summary.mistakes.first?.id, decision.id)
        XCTAssertNotNil(summary.weakestTopic)
        XCTAssertLessThan(try XCTUnwrap(summary.strategyAccuracy), 1)
        XCTAssertNil(summary.countAccuracy)
        XCTAssertTrue(summary.countResponses.isEmpty)
    }

    func testInsuranceIsGradedWithoutLeakingTheDealerHoleCard() throws {
        for takeInsurance in [false, true] {
            var session = SimulationSession(configuration: .init(mode: .test, countChecks: false), seed: 1,
                                            shoe: shoe(.ten, .ace, .nine, .king))
            XCTAssertTrue(session.startNextRound())
            XCTAssertEqual(session.game.phase, .insurance)
            XCTAssertFalse(session.game.holeRevealed)
            XCTAssertEqual(session.game.visibleDealerCards.count, 1)
            XCTAssertEqual(session.game.runningCount, -2)
            XCTAssertTrue(session.play(takeInsurance ? .insurance : .declineInsurance))
            let decision = try XCTUnwrap(session.decisions.first)
            XCTAssertEqual(decision.topic, .insurance)
            XCTAssertEqual(decision.recommended, .declineInsurance)
            XCTAssertEqual(decision.correct, !takeInsurance)
            XCTAssertEqual(decision.cards.map(\.rank), [.ten, .nine])
            XCTAssertEqual(decision.dealer.rank, .ace)
            XCTAssertEqual(Set(decision.availableChoices.map(\.rawValue)), Set(["insurance", "declineInsurance"]))
            XCTAssertEqual(session.game.runningCount, -3)
            XCTAssertTrue(session.game.holeRevealed)
            XCTAssertEqual(session.stage, .roundReview)
            XCTAssertEqual(session.decisions.count, 1)
        }
    }

    func testIllegalActionsDoNotAdvanceOrImproveTheScore() {
        var session = SimulationSession(configuration: .init(mode: .test, countChecks: false), seed: 9,
                                        shoe: shoe(.ten, .six, .eight, .nine, .ten))
        XCTAssertFalse(session.play(.stand))
        XCTAssertFalse(session.finishRound())
        XCTAssertFalse(session.submitCount(0))
        XCTAssertTrue(session.startNextRound())
        let game = session.game
        for action in [GameAction.split, .insurance, .declineInsurance, .shuffle, .deal(betCents: 100)] {
            XCTAssertFalse(session.play(action))
        }
        XCTAssertEqual(session.game, game)
        XCTAssertTrue(session.decisions.isEmpty)
        XCTAssertTrue(session.play(.stand))
        XCTAssertEqual(session.decisions.count, 1)
        XCTAssertFalse(session.play(.stand))
        XCTAssertEqual(session.decisions.count, 1)
    }

    func testCountChecksWaitForHoleRevealAndRecordOnlyTheFirstAnswer() throws {
        var session = SimulationSession(configuration: .init(mode: .guided, countChecks: true), seed: 1,
                                        shoe: shoe(.ten, .six, .seven, .ten, .ten))
        XCTAssertTrue(session.startNextRound())
        XCTAssertEqual(session.game.runningCount, 0)
        XCTAssertFalse(session.beginCountCheck())
        XCTAssertFalse(session.submitCount(0))
        XCTAssertTrue(session.play(.stand))
        XCTAssertFalse(session.beginCountCheck())
        XCTAssertTrue(session.continueDecisionFeedback())
        XCTAssertEqual(session.game.runningCount, -2)
        XCTAssertFalse(session.finishRound())
        XCTAssertTrue(session.beginCountCheck())
        XCTAssertEqual(session.stage, .countCheck)
        XCTAssertFalse(session.submitCount(Int.max))
        XCTAssertFalse(session.submitCount(Int.min))
        XCTAssertFalse(session.finishRound())
        XCTAssertTrue(session.submitCount(0))
        XCTAssertEqual(session.stage, .countFeedback)
        let response = try XCTUnwrap(session.countResponses.first)
        XCTAssertEqual(response.round, 1)
        XCTAssertEqual(response.expectedCount, -2)
        XCTAssertEqual(response.answer, 0)
        XCTAssertFalse(response.correct)
        XCTAssertFalse(session.submitCount(-2))
        XCTAssertEqual(session.countResponses.count, 1)
        XCTAssertEqual(session.countResponses.first?.answer, 0)
        XCTAssertTrue(session.finishRound())
        XCTAssertEqual(session.completedRounds, 1)
    }

    func testCountMistakesProduceRelevantPracticeInsteadOfAWinRateScore() throws {
        var session = SimulationSession(configuration: .init(rounds: 10, mode: .test, countChecks: true), seed: 123)
        complete(&session, countOffset: 1)
        let summary = try XCTUnwrap(session.summary())
        XCTAssertEqual(summary.countAccuracy, 0)
        XCTAssertEqual(summary.countMistakes.count, 10)
        XCTAssertEqual(summary.strategyAccuracy, 1)
        XCTAssertEqual(summary.suggestedDrill, .runningCount)
        XCTAssertTrue(summary.mistakes.isEmpty)
        XCTAssertTrue(summary.isValidForRestore)
    }

    func testFreshShoeNotificationMatchesTheCountResetAtTheCutCard() throws {
        var session = SimulationSession(configuration: .init(rounds: 50, mode: .test, countChecks: false, rules: Rules(decks: 4)), seed: 99)
        var previousSeed = session.game.seed
        var previousShoeNumber = session.shoeNumber
        var shuffles = 0
        for round in 1...50 {
            XCTAssertTrue(session.startNextRound())
            let shuffled = session.game.seed != previousSeed
            XCTAssertEqual(session.roundStartedNewShoe, shuffled || round == 1)
            if shuffled {
                shuffles += 1
                XCTAssertEqual(session.shoeNumber, previousShoeNumber + 1)
                let visible = session.game.hands.flatMap(\.cards) + session.game.visibleDealerCards
                XCTAssertEqual(session.game.runningCount, visible.reduce(0) { $0 + $1.hiLoValue })
            } else { XCTAssertEqual(session.shoeNumber, previousShoeNumber) }
            previousSeed = session.game.seed
            previousShoeNumber = session.shoeNumber
            for _ in 0..<128 where session.stage == .playing {
                XCTAssertTrue(session.play(session.game.phase == .insurance ? .declineInsurance : .stand))
            }
            XCTAssertEqual(session.stage, .roundReview)
            XCTAssertTrue(session.finishRound())
        }
        XCTAssertGreaterThan(shuffles, 0)
        XCTAssertEqual(session.stage, .complete)
    }

    func testNormalShoesKeepAReserveAndNeverShuffleInsideARound() {
        for decks in [4, 6, 8] {
            for seed: UInt64 in [7, 40, 104] {
                var session = SimulationSession(configuration: .init(rounds: 50, mode: .test, countChecks: false,
                                            rules: Rules(decks: decks, hitSoft17: true, doubleAfterSplit: false, surrender: false)), seed: seed)
                for _ in 0..<50 {
                    XCTAssertTrue(session.startNextRound())
                    XCTAssertGreaterThanOrEqual(session.game.cutCard, 64)
                    for _ in 0..<128 where session.stage == .playing {
                        let action = session.game.phase == .insurance ? GameAction.declineInsurance
                            : BasicStrategy.recommend(in: session.game)!.move.action
                        XCTAssertTrue(session.play(action))
                        XCTAssertGreaterThanOrEqual(session.game.cutCard, 64)
                        XCTAssertFalse(session.shoeChangedDuringRound)
                    }
                    XCTAssertEqual(session.stage, .roundReview)
                    XCTAssertTrue(session.finishRound())
                }
                XCTAssertEqual(session.stage, .complete)
                XCTAssertTrue(session.isValidForRestore)
            }
        }
    }

    func testSeededPlayAndRestoreProduceTheSameCardsAndScores() throws {
        var original = SimulationSession(configuration: .init(rounds: 25, mode: .guided, countChecks: true), seed: 2_026)
        XCTAssertTrue(original.startNextRound())
        let restored = try JSONDecoder().decode(SimulationSession.self, from: JSONEncoder().encode(original))
        XCTAssertTrue(restored.isValidForRestore)
        XCTAssertEqual(restored.game, original.game)
        XCTAssertEqual(restored.id, original.id)
        var resumed = restored
        complete(&original)
        complete(&resumed)
        XCTAssertEqual(resumed.game, original.game)
        XCTAssertEqual(resumed.decisions.map(\.chosen), original.decisions.map(\.chosen))
        XCTAssertEqual(resumed.decisions.map(\.recommended), original.decisions.map(\.recommended))
        XCTAssertEqual(resumed.countResponses.map(\.expectedCount), original.countResponses.map(\.expectedCount))
        XCTAssertEqual(resumed.summary()?.strategyAccuracy, original.summary()?.strategyAccuracy)
        XCTAssertEqual(resumed.summary()?.countAccuracy, original.summary()?.countAccuracy)
    }

    func testRestoreRejectsImpossibleStagesRoundLimitsAndDuplicateRecords() throws {
        let fresh = SimulationSession(configuration: .init(mode: .test, countChecks: true), seed: 42)
        let unfunded = try altered(fresh) {
            var game = $0["game"] as! [String: Any]
            game["bankrollCents"] = 99
            $0["game"] = game
        }
        XCTAssertTrue(unfunded.game.isValidForRestore)
        XCTAssertFalse(unfunded.isValidForRestore)
        XCTAssertFalse(try altered(fresh) { $0["stage"] = "complete" }.isValidForRestore)
        XCTAssertFalse(try altered(fresh) { $0["completedRounds"] = 11 }.isValidForRestore)
        XCTAssertFalse(try altered(fresh) {
            var config = $0["configuration"] as! [String: Any]
            config["rounds"] = 999
            $0["configuration"] = config
        }.isValidForRestore)
        var active = SimulationSession(configuration: .init(mode: .test, countChecks: true), seed: 1,
                                       shoe: shoe(.ten, .six, .seven, .ten, .ten))
        XCTAssertTrue(active.startNextRound())
        for ranks: [Rank] in [[.ace, .king], [.ten, .ten, .ten]] {
            let unplayable = try altered(active) {
                var game = $0["game"] as! [String: Any]
                var hands = game["hands"] as! [[String: Any]]
                hands[0]["cards"] = ranks.map { ["rank": $0.rawValue, "suit": "spades"] }
                game["hands"] = hands
                $0["game"] = game
            }
            XCTAssertTrue(unplayable.game.isValidForRestore)
            XCTAssertFalse(unplayable.isValidForRestore)
        }
        var finished = fresh
        complete(&finished)
        XCTAssertFalse(try altered(finished) {
            var records = $0["decisions"] as! [[String: Any]]
            records.append(records[0])
            $0["decisions"] = records
        }.isValidForRestore)
        XCTAssertFalse(try altered(finished) {
            var responses = $0["countResponses"] as! [[String: Any]]
            responses[0]["answer"] = Int.max
            $0["countResponses"] = responses
        }.isValidForRestore)
        let inconsistentLedger = try altered(finished) {
            var game = $0["game"] as! [String: Any]
            var history = game["history"] as! [[String: Any]]
            history[0]["bankrollCents"] = (history[0]["bankrollCents"] as! NSNumber).intValue + 1
            game["history"] = history
            $0["game"] = game
        }
        XCTAssertTrue(inconsistentLedger.game.isValidForRestore)
        XCTAssertFalse(inconsistentLedger.isValidForRestore)
        let summary = try XCTUnwrap(finished.summary())
        XCTAssertFalse(try altered(summary) { $0["completedRounds"] = 9 }.isValidForRestore)
        XCTAssertFalse(try altered(summary) { $0["countResponses"] = [] }.isValidForRestore)
        XCTAssertFalse(try altered(summary) {
            var records = $0["decisions"] as! [[String: Any]]
            records.append(records[0])
            $0["decisions"] = records
        }.isValidForRestore)
    }

    func testRecordValidationRejectsImpossibleHandsAndForgedAdvice() throws {
        var session = SimulationSession(configuration: .init(mode: .test, countChecks: false), seed: 1,
                                        shoe: shoe(.ten, .six, .seven, .ten, .ten))
        XCTAssertTrue(session.startNextRound())
        XCTAssertTrue(session.play(.stand))
        let decision = try XCTUnwrap(session.decisions.first)
        XCTAssertTrue(decision.isValidForRestore)
        XCTAssertFalse(try altered(decision) { $0["recommended"] = "hit" }.isValidForRestore)
        XCTAssertFalse(try altered(decision) {
            $0["cards"] = Array(repeating: ["rank": "10", "suit": "spades"], count: 3)
            $0["availableChoices"] = ["hit", "stand"]
        }.isValidForRestore)
        XCTAssertFalse(try altered(decision) {
            $0["cards"] = [["rank": "A", "suit": "spades"], ["rank": "K", "suit": "clubs"]]
            $0["availableChoices"] = ["hit", "stand"]
            $0["topic"] = "soft"
        }.isValidForRestore)
    }

    func testPracticeTimingRejectsInvalidIntervalsAndStopsAtCompletion() throws {
        var session = SimulationSession(configuration: .init(mode: .test, countChecks: false), seed: 72)
        XCTAssertTrue(session.recordPracticeTime(12.5))
        XCTAssertTrue(session.recordPracticeTime(20))
        XCTAssertEqual(session.elapsedSeconds, 32.5)
        for invalid in [Double.nan, .infinity, -.infinity, -1] {
            XCTAssertFalse(session.recordPracticeTime(invalid))
            XCTAssertEqual(session.elapsedSeconds, 32.5)
        }
        let restored = try JSONDecoder().decode(SimulationSession.self, from: JSONEncoder().encode(session))
        XCTAssertEqual(restored.elapsedSeconds, 32.5)
        XCTAssertTrue(session.recordPracticeTime(Double.greatestFiniteMagnitude))
        XCTAssertEqual(session.elapsedSeconds, 86_400)
        XCTAssertTrue(session.isValidForRestore)
        complete(&session)
        XCTAssertFalse(session.recordPracticeTime(1))
        XCTAssertEqual(try XCTUnwrap(session.summary()).elapsedSeconds, 86_400)
        XCTAssertNil(session.summary(date: Date(timeIntervalSinceReferenceDate: .infinity)))
    }

    func testFeedbackAndCountPromptRestoreWithoutRepeatingScoredDecisions() throws {
        var session = SimulationSession(configuration: .init(mode: .guided, countChecks: true), seed: 1,
                                        shoe: shoe(.ten, .six, .seven, .ten, .ten))
        XCTAssertTrue(session.startNextRound())
        XCTAssertTrue(session.play(.stand))
        session = try JSONDecoder().decode(SimulationSession.self, from: JSONEncoder().encode(session))
        XCTAssertEqual(session.stage, .decisionFeedback)
        XCTAssertTrue(session.isValidForRestore)
        XCTAssertFalse(session.play(.stand))
        XCTAssertEqual(session.decisions.count, 1)
        XCTAssertTrue(session.continueDecisionFeedback())
        XCTAssertTrue(session.beginCountCheck())
        session = try JSONDecoder().decode(SimulationSession.self, from: JSONEncoder().encode(session))
        XCTAssertEqual(session.stage, .countCheck)
        XCTAssertTrue(session.isValidForRestore)
        XCTAssertTrue(session.submitCount(-2))
        session = try JSONDecoder().decode(SimulationSession.self, from: JSONEncoder().encode(session))
        XCTAssertEqual(session.stage, .countFeedback)
        XCTAssertTrue(session.isValidForRestore)
        XCTAssertFalse(try altered(session) {
            var responses = $0["countResponses"] as! [[String: Any]]
            responses[0]["expectedCount"] = -1
            $0["countResponses"] = responses
        }.isValidForRestore)
        XCTAssertFalse(session.submitCount(-2))
        XCTAssertEqual(session.countResponses.count, 1)
        XCTAssertTrue(session.finishRound())
    }
}
