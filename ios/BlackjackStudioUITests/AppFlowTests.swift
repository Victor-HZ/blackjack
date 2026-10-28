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
    func testCaptureRepresentativeNativeScreens() {
        for appearance in ["Light", "Dark"] {
            app.launchArguments = ["--ui-testing", "--reset-state", "--skip-onboarding", "-AppleInterfaceStyle", appearance]
            app.launch()
            XCTAssertTrue(app.buttons["startSession"].waitForExistence(timeout: 10))
            attach("\(appearance)-01-practice")
            app.tabBars.buttons["Learn"].tap(); attach("\(appearance)-02-lessons")
            app.tabBars.buttons["Table"].tap(); attach("\(appearance)-03-table")
            app.tabBars.buttons["Progress"].tap(); attach("\(appearance)-04-progress")
            app.terminate()
        }
    }
    private func reveal(_ element: XCUIElement) {
        for _ in 0..<6 where !element.isHittable { app.swipeUp() }
    }
    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways
        add(attachment)
    }
}
