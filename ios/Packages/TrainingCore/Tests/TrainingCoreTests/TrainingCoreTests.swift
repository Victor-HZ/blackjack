import XCTest
@testable import TrainingCore

final class TrainingCoreTests: XCTestCase {
    func testHiLoValuesIgnoreSuits() {
        for suit in ["♠", "♥", "♦", "♣"] {
            for rank in ["2", "3", "4", "5", "6"] { XCTAssertEqual(TrainingCard(rank: rank, suit: suit).hiLo, 1) }
            for rank in ["7", "8", "9"] { XCTAssertEqual(TrainingCard(rank: rank, suit: suit).hiLo, 0) }
            for rank in ["10", "J", "Q", "K", "A"] { XCTAssertEqual(TrainingCard(rank: rank, suit: suit).hiLo, -1) }
        }
    }
    func testGeneratedPromptsAreDeterministicForEveryKind() {
        for kind in DrillKind.allCases {
            XCTAssertEqual(PromptFactory.make(kind: kind, seed: 2026), PromptFactory.make(kind: kind, seed: 2026))
            XCTAssertFalse(PromptFactory.make(kind: kind, seed: 2026).isEmpty)
        }
    }
    func testShoeStaminaUsesEveryCardOnceAndChecksAlongTheWay() {
        let prompts = PromptFactory.make(kind: .fullDeck, seed: 5)
        let cards = prompts.flatMap(\.cards)
        XCTAssertEqual(prompts.count, 13)
        XCTAssertEqual(cards.count, 52)
        XCTAssertEqual(Set(cards.map(\.id)).count, 52)
        XCTAssertEqual(prompts.last?.expectedAnswer, 0)
        XCTAssertTrue(prompts.dropLast().contains { $0.expectedAnswer != 0 })
        var running = 0
        for prompt in prompts {
            XCTAssertEqual(prompt.previousCount, running)
            running += prompt.cards.reduce(0) { $0 + $1.hiLo }
            XCTAssertEqual(prompt.expectedAnswer, Double(running))
        }
    }
    func testRunningCountCarriesBetweenPrompts() {
        let prompts = PromptFactory.make(kind: .runningCount, seed: 27)
        var count = 0
        for prompt in prompts {
            XCTAssertEqual(prompt.cards.count, 1)
            count += prompt.cards[0].hiLo
            XCTAssertEqual(prompt.expectedAnswer, Double(count))
        }
    }
    func testPairAnswersIncludeBothValues() {
        for prompt in PromptFactory.make(kind: .pairs, seed: 11) {
            XCTAssertEqual(prompt.cards.count, 2)
            XCTAssertEqual(prompt.expectedAnswer, Double(prompt.cards.reduce(0) { $0 + $1.hiLo }))
        }
    }
    func testTrueCountUsesRemainingDecksAndTruncatesNegativeValuesTowardZero() {
        var foundNegativeFraction = false
        for seed in 1...30 {
            for prompt in PromptFactory.make(kind: .trueCount, seed: UInt64(seed)) {
                let quotient = Double(prompt.runningCount!) / prompt.decksRemaining!
                XCTAssertEqual(prompt.expectedAnswer, quotient.rounded(.towardZero))
                if quotient < 0 && quotient != quotient.rounded() {
                    foundNegativeFraction = true
                    XCTAssertGreaterThan(prompt.expectedAnswer, quotient)
                }
            }
        }
        XCTAssertTrue(foundNegativeFraction)
    }
    func testDeckEstimationCoversEveryHalfDeckWithoutRepeats() {
        let prompts = PromptFactory.make(kind: .deckEstimation, seed: 17)
        XCTAssertEqual(Set(prompts.map(\.expectedAnswer)), Set((1...12).map { Double($0) / 2 }))
        for prompt in prompts { XCTAssertEqual(prompt.expectedAnswer, prompt.decksRemaining) }
    }
    func testSessionRejectsDoubleSubmissionAndAdvanceBeforeAnswer() {
        var session = DrillSession(kind: .cardValues, seed: 3)
        XCTAssertFalse(session.advance())
        let expected = session.currentPrompt!.expectedAnswer
        XCTAssertNil(session.submit(answer: .nan, elapsedSeconds: 0))
        XCTAssertNil(session.submit(answer: expected, elapsedSeconds: .infinity))
        XCTAssertNil(session.submit(answer: expected, elapsedSeconds: -1))
        XCTAssertNotNil(session.submit(answer: expected, elapsedSeconds: 2))
        XCTAssertNil(session.submit(answer: expected, elapsedSeconds: 2))
        XCTAssertEqual(session.responses.count, 1)
        XCTAssertEqual(session.correct, 1)
        XCTAssertTrue(session.advance())
        XCTAssertNil(session.currentResponse)
    }
    func testSummaryRecordsActualAccuracyAndReviewableMistakes() {
        var session = DrillSession(kind: .runningCount, seed: 22)
        while let prompt = session.currentPrompt {
            let answer = prompt.id.isMultiple(of: 2) ? prompt.expectedAnswer : prompt.expectedAnswer + 1
            session.submit(answer: answer, elapsedSeconds: 2.5)
            session.advance()
        }
        let summary = session.summary()
        XCTAssertTrue(session.isComplete)
        XCTAssertEqual(summary.total, 12)
        XCTAssertEqual(summary.correct, 6)
        XCTAssertEqual(summary.accuracyPercent, 50)
        XCTAssertEqual(summary.mistakes.count, 6)
        XCTAssertEqual(summary.elapsedSeconds, 30)
        XCTAssertEqual(summary.secondsPerAnswer, 2.5)
        XCTAssertTrue(summary.isValidForRestore)
        XCTAssertNil(session.submit(answer: 0, elapsedSeconds: 1))
        XCTAssertFalse(session.advance())
    }
    func testAllGeneratedCompleteSummariesCanBeRestored() {
        for kind in DrillKind.allCases {
            var session = DrillSession(kind: kind, seed: 444)
            while let prompt = session.currentPrompt { session.submit(answer: prompt.expectedAnswer, elapsedSeconds: 1.25); session.advance() }
            let data = try! JSONEncoder().encode(session.summary())
            let decoded = try! JSONDecoder().decode(DrillSummary.self, from: data)
            XCTAssertTrue(decoded.isValidForRestore)
            XCTAssertEqual(decoded.accuracy, 1)
        }
    }
    func testCorruptSummariesAreRejected() {
        XCTAssertFalse(DrillSummary(kind: .cardValues, correct: 10, total: 3, elapsedSeconds: 4).isValidForRestore)
        XCTAssertFalse(DrillSummary(kind: .cardValues, correct: 0, total: 3, elapsedSeconds: .infinity).isValidForRestore)
        XCTAssertFalse(DrillSummary(kind: .cardValues, correct: 0, total: 0, elapsedSeconds: 0).isValidForRestore)
        XCTAssertFalse(DrillSummary(kind: .cardValues, correct: 0, total: 3, elapsedSeconds: 90_000).isValidForRestore)
        let huge = DrillPrompt(id: 0, kind: .cardValues, expectedAnswer: 1e40, explanation: "Invalid")
        let mistake = DrillResponse(prompt: huge, answer: 0, elapsedSeconds: 1)
        XCTAssertFalse(DrillSummary(kind: .cardValues, correct: 0, total: 1, elapsedSeconds: 1, mistakes: [mistake]).isValidForRestore)
        let invalidCard = DrillPrompt(id: 0, kind: .pairs, cards: [TrainingCard(rank: "99", suit: "x")], expectedAnswer: 1, explanation: "Invalid")
        XCTAssertFalse(DrillSummary(kind: .pairs, correct: 0, total: 1, elapsedSeconds: 1, mistakes: [DrillResponse(prompt: invalidCard, answer: 0, elapsedSeconds: 1)]).isValidForRestore)
    }
    func testCorrectAnswersCannotBeStoredAsMistakes() {
        let prompt = DrillPrompt(id: 0, kind: .cardValues, expectedAnswer: 1, explanation: "One")
        let response = DrillResponse(prompt: prompt, answer: 1, elapsedSeconds: 1)
        XCTAssertFalse(DrillSummary(kind: .cardValues, correct: 0, total: 1, elapsedSeconds: 1, mistakes: [response]).isValidForRestore)
    }
    func testNumberFormattingCannotTrapOnMalformedNumbers() {
        XCTAssertEqual(DrillPrompt.format(.nan), "—")
        XCTAssertEqual(DrillPrompt.format(.infinity), "—")
        XCTAssertFalse(DrillPrompt.format(1e40).isEmpty)
        XCTAssertEqual(DrillPrompt.format(-2), "-2")
        XCTAssertEqual(DrillPrompt.format(2, signed: true), "+2")
        XCTAssertEqual(DrillPrompt.format(1.5), "1.5")
    }
    func testRecommendationRespectsAccessAndTargetsWeakness() {
        let history = [DrillSummary(kind: .cardValues, correct: 15, total: 15, elapsedSeconds: 30), DrillSummary(kind: .runningCount, correct: 5, total: 12, elapsedSeconds: 40)]
        XCTAssertEqual(TrainingRecommendation.next(history: history, hasPro: false), .runningCount)
        XCTAssertEqual(TrainingRecommendation.next(history: [], hasPro: false), .cardValues)
        XCTAssertFalse(TrainingRecommendation.next(history: history, hasPro: false).isPremium)
    }
    func testCurriculumHasUniqueLessonsAndValidChecks() {
        XCTAssertEqual(Curriculum.lessons.count, 8)
        XCTAssertEqual(Set(Curriculum.lessons.map(\.id)).count, 8)
        XCTAssertFalse(Curriculum.lessons[0].isPremium)
        XCTAssertFalse(Curriculum.lessons[1].isPremium)
        XCTAssertFalse(Curriculum.lessons.last!.isPremium, "Safety boundaries are available without purchase")
        for lesson in Curriculum.lessons {
            XCTAssertGreaterThanOrEqual(lesson.steps.count, 2)
            XCTAssertEqual(lesson.questions.count, 3)
            for question in lesson.questions { XCTAssertTrue(question.options.indices.contains(question.correctIndex)) }
        }
    }
}
