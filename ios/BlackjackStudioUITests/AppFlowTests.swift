import XCTest

/// Runs against an actual iOS simulator/device in Xcode. Not executed by Linux core tests.
@MainActor
final class AppFlowTests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-state", "--skip-onboarding"]
    }
    func testOnboardingIsShortAndDoesNotRequirePurchaseOrNotificationPermission() {
        app.launchArguments = ["--ui-testing", "--reset-state"]
        app.launch()
        let next = app.buttons["onboardingContinue"]
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        reveal(next)
        next.tap()
        XCTAssertTrue(app.staticTexts["Where are you starting?"].waitForExistence(timeout: 3))
        reveal(next)
        next.tap()
        XCTAssertTrue(app.tabBars.buttons["Train"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["startSession"].exists)
        XCTAssertFalse(app.buttons["paywall.purchase"].exists)
    }
    func testFreeDrillCompletesAndProgressSurvivesRelaunch() {
        app.launch()
        let start = app.buttons["startSession"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        reveal(start); start.tap()
        for _ in 0..<50 {
            if app.buttons["Finish session"].exists { break }
            let answer = app.buttons["Answer 0"]
            XCTAssertTrue(answer.waitForExistence(timeout: 4))
            reveal(answer); answer.tap()
            let next = app.buttons["Next"]
            let results = app.buttons["See results"]
            if results.waitForExistence(timeout: 0.3) { reveal(results); results.tap() }
            else { XCTAssertTrue(next.waitForExistence(timeout: 3)); reveal(next); next.tap() }
        }
        XCTAssertTrue(app.buttons["Finish session"].waitForExistence(timeout: 4))
        // Completed results are saved before closing; ending the app must not lose the session.
        app.terminate()
        app.launchArguments = ["--ui-testing", "--skip-onboarding"]
        app.launch()
        app.tabBars.buttons["Progress"].tap()
        XCTAssertTrue(app.navigationBars["Progress"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["progress.sessions"].label.contains("1"))
    }
    func testPauseHidesTheQuestionAndResumesWithoutEndingTheSession() {
        app.launch()
        let start = app.buttons["startSession"]
        XCTAssertTrue(start.waitForExistence(timeout: 10)); reveal(start); start.tap()
        app.buttons["Pause session"].tap()
        XCTAssertTrue(app.staticTexts["The timer is paused."].waitForExistence(timeout: 3))
        app.buttons["Resume"].tap()
        XCTAssertTrue(app.buttons["Answer 0"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["The timer is paused."].exists)
    }
    func testSimulatedTableSettlesWithoutExposingTheHoleCardEarly() {
        app.launch()
        app.tabBars.buttons["Table"].tap()
        let deal = app.buttons["table.deal"]
        XCTAssertTrue(deal.waitForExistence(timeout: 10))
        let canDeal = NSPredicate(format: "enabled == true")
        expectation(for: canDeal, evaluatedWith: deal)
        waitForExpectations(timeout: 15)
        deal.tap()
        if app.buttons["table.decline-insurance"].exists { app.buttons["table.decline-insurance"].tap() }
        if app.buttons["table.stand"].exists {
            XCTAssertTrue(app.otherElements["Face-down card"].exists || app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'face down'")).count > 0)
            app.buttons["table.stand"].tap()
        }
        XCTAssertTrue(app.descendants(matching: .any)["table.result"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["table.deal"].exists)
    }
    func testFreePremiumEntryShowsAnHonestDismissiblePaywall() {
        app.launch()
        let premium = app.buttons["drill-pairs"]
        XCTAssertTrue(premium.waitForExistence(timeout: 10)); reveal(premium); premium.tap()
        XCTAssertTrue(app.buttons["paywall.purchase"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["One purchase. No subscription."].exists)
        app.buttons["paywall.close"].tap()
        XCTAssertTrue(app.tabBars.buttons["Train"].waitForExistence(timeout: 3))
    }
    func testStrategyReferenceUsesHypotheticalHandsAndRuleAwareAdvice() {
        app.launch()
        app.tabBars.buttons["Learn"].tap()
        let guide = app.buttons["learn.strategy-guide"]
        XCTAssertTrue(guide.waitForExistence(timeout: 5)); reveal(guide); guide.tap()
        XCTAssertTrue(app.staticTexts["Study a sample hand"].waitForExistence(timeout: 5))
        let recommendation = app.descendants(matching: .any)["strategy.recommendation"]
        XCTAssertTrue(recommendation.label.contains("Surrender"))
        app.descendants(matching: .any)["strategy.firstCard"].tap()
        app.buttons["8"].firstMatch.tap()
        app.descendants(matching: .any)["strategy.secondCard"].tap()
        app.buttons["8"].firstMatch.tap()
        app.descendants(matching: .any)["strategy.dealerCard"].tap()
        app.buttons["6"].firstMatch.tap()
        XCTAssertTrue(recommendation.label.contains("Split"))
    }
    func testTenRoundSimulationEndsExactlyAndItsResultsSurviveRelaunch() {
        app.launchArguments.append("--simulation-seed=1234")
        app.launch()
        openSimulation()
        let testMode = app.buttons["simulation.mode.test"]
        reveal(testMode); testMode.tap()
        let checks = app.switches["simulation.countChecks"]
        XCTAssertTrue(checks.exists)
        if checks.value as? String == "1" { reveal(checks); checks.tap() }
        let start = app.buttons["simulation.start"]
        reveal(start); start.tap()
        for round in 1...10 {
            let deal = app.buttons["simulation.deal"]
            XCTAssertTrue(deal.waitForExistence(timeout: 5))
            reveal(deal); deal.tap()
            XCTAssertEqual(app.descendants(matching: .any)["simulation.roundProgress"].label, "Round \(round) of 10")
            if app.buttons["simulation.declineInsurance"].exists {
                let decline = app.buttons["simulation.declineInsurance"]
                reveal(decline); decline.tap()
            }
            if app.buttons["simulation.move.stand"].exists {
                let stand = app.buttons["simulation.move.stand"]
                reveal(stand); stand.tap()
            }
            XCTAssertFalse(app.descendants(matching: .any)["simulation.decisionFeedback"].exists)
            XCTAssertFalse(app.descendants(matching: .any)["simulation.results"].exists)
            let next = app.buttons["simulation.finishRound"]
            XCTAssertTrue(next.waitForExistence(timeout: 5))
            reveal(next); next.tap()
        }
        XCTAssertTrue(app.descendants(matching: .any)["simulation.results"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["simulation.deal"].exists)
        XCTAssertFalse(app.buttons["simulation.finishRound"].exists)
        app.terminate()
        app.launchArguments = ["--ui-testing", "--skip-onboarding"]
        app.launch()
        app.tabBars.buttons["Progress"].tap()
        let history = app.descendants(matching: .any)["simulation.history"]
        XCTAssertTrue(history.waitForExistence(timeout: 5))
        let result = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'simulation.history.'")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5), "Saved simulation row is missing from Progress.")
        reveal(result); result.tap()
        XCTAssertTrue(app.descendants(matching: .any)["simulation.results"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["10 rounds · Test"].exists)
    }
    func testGuidedSimulationRequiresFeedbackAndOneCountAnswerBeforeAdvancing() {
        app.launchArguments.append("--simulation-seed=1234")
        app.launch()
        openSimulation()
        let start = app.buttons["simulation.start"]
        reveal(start); start.tap()
        var sawFeedback = false
        for _ in 0..<10 {
            let deal = app.buttons["simulation.deal"]
            XCTAssertTrue(deal.waitForExistence(timeout: 5))
            reveal(deal); deal.tap()
            for _ in 0..<4 {
                if app.buttons["simulation.declineInsurance"].exists {
                    let decline = app.buttons["simulation.declineInsurance"]
                    reveal(decline); decline.tap()
                } else if app.buttons["simulation.move.stand"].exists {
                    let stand = app.buttons["simulation.move.stand"]
                    reveal(stand); stand.tap()
                }
                let next = app.buttons["simulation.continueDecision"]
                if next.exists {
                    sawFeedback = true
                    XCTAssertTrue(app.descendants(matching: .any)["simulation.decisionFeedback"].exists)
                    XCTAssertFalse(app.buttons["simulation.deal"].exists)
                    XCTAssertFalse(app.buttons["simulation.move.stand"].exists)
                    XCTAssertFalse(app.buttons["simulation.finishRound"].exists)
                    reveal(next); next.tap()
                }
                if app.buttons["simulation.beginCount"].exists { break }
            }
            let beginCount = app.buttons["simulation.beginCount"]
            XCTAssertTrue(beginCount.waitForExistence(timeout: 5))
            XCTAssertFalse(app.buttons["simulation.finishRound"].exists)
            reveal(beginCount); beginCount.tap()
            let answer = app.textFields["simulation.countAnswer"]
            XCTAssertTrue(answer.waitForExistence(timeout: 3))
            XCTAssertFalse(app.otherElements["Face-down card"].exists)
            XCTAssertEqual(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS ' of spades' OR label CONTAINS ' of hearts' OR label CONTAINS ' of clubs' OR label CONTAINS ' of diamonds'")).count, 0)
            XCTAssertFalse(app.buttons["simulation.finishRound"].exists)
            let submit = app.buttons["simulation.submitCount"]
            XCTAssertFalse(submit.isEnabled)
            reveal(answer); answer.tap(); answer.typeText("-416")
            reveal(submit); submit.tap()
            XCTAssertTrue(app.descendants(matching: .any)["simulation.countFeedback"].waitForExistence(timeout: 3))
            XCTAssertFalse(app.textFields["simulation.countAnswer"].exists)
            XCTAssertFalse(app.buttons["simulation.submitCount"].exists)
            let nextRound = app.buttons["simulation.finishRound"]
            XCTAssertTrue(nextRound.exists)
            if sawFeedback { break }
            reveal(nextRound); nextRound.tap()
        }
        XCTAssertTrue(sawFeedback, "A guided decision must pause for feedback before the next action.")
    }
    private func openSimulation() {
        let entry = app.buttons["simulation.open"]
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        reveal(entry); entry.tap()
        XCTAssertTrue(app.buttons["simulation.start"].waitForExistence(timeout: 5))
    }
    func testCaptureRepresentativeNativeScreens() {
        for appearance in ["Light", "Dark"] {
            app.launchArguments = ["--ui-testing", "--reset-state", "--skip-onboarding", "--simulation-seed=1234", "-AppleInterfaceStyle", appearance]
            app.launch()
            XCTAssertTrue(app.buttons["startSession"].waitForExistence(timeout: 10))
            attach("\(appearance)-01-practice")
            app.tabBars.buttons["Learn"].tap(); attach("\(appearance)-02-lessons")
            app.tabBars.buttons["Table"].tap(); attach("\(appearance)-03-table")
            app.tabBars.buttons["Progress"].tap(); attach("\(appearance)-04-progress")
            app.tabBars.buttons["Train"].tap()
            openSimulation(); attach("\(appearance)-05-simulation-setup")
            let start = app.buttons["simulation.start"]
            reveal(start); start.tap()
            let deal = app.buttons["simulation.deal"]
            XCTAssertTrue(deal.waitForExistence(timeout: 5))
            reveal(deal); deal.tap(); attach("\(appearance)-06-simulation-table")
            app.terminate()
        }
    }
    private func reveal(_ element: XCUIElement) {
        for _ in 0..<6 where !element.isHittable { app.swipeUp() }
        for _ in 0..<6 where !element.isHittable { app.swipeDown() }
    }
    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways
        add(attachment)
    }
}
