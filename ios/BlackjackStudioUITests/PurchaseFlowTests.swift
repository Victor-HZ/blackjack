import XCTest
import StoreKitTest

/// Uses Xcode's local StoreKit environment, never a production charge.
@MainActor
final class PurchaseFlowTests: XCTestCase {
    private var store: SKTestSession!
    private var app: XCUIApplication!
    private var productID = ""

    override func setUpWithError() throws {
        continueAfterFailure = false
        let url = try XCTUnwrap(Bundle(for: PurchaseFlowTests.self).url(forResource: "BlackjackStudio", withExtension: "storekit"))
        let config = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let products = try XCTUnwrap(config["products"] as? [[String: Any]])
        productID = try XCTUnwrap(products.first?["productID"] as? String)
        store = try SKTestSession(configurationFileNamed: "BlackjackStudio")
        store.resetToDefaultState()
        store.disableDialogs = true
        store.clearTransactions()
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-state", "--skip-onboarding"]
    }
    override func tearDownWithError() throws { app?.terminate(); store?.clearTransactions() }

    func testOneTimePurchaseUnlocksPremiumTrainingAndSurvivesRelaunch() throws {
        app.launch()
        openPairs()
        let buy = app.buttons["paywall.purchase"]
        XCTAssertTrue(buy.waitForExistence(timeout: 10))
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: buy)
        waitForExpectations(timeout: 15)
        buy.tap()
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: buy)
        waitForExpectations(timeout: 15)
        XCTAssertTrue(app.tabBars.buttons["Train"].waitForExistence(timeout: 15))
        app.terminate()
        app.launchArguments = ["--ui-testing", "--skip-onboarding"]
        app.launch()
        openPairs()
        XCTAssertTrue(app.navigationBars["Pair cancellation"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["paywall.purchase"].exists)
        XCTAssertEqual(store.allTransactions().filter { $0.productIdentifier == productID }.count, 1)
    }
    func testRefundRemovesPremiumAccess() async throws {
        let transaction = try await store.buyProduct(identifier: productID)
        app.launch()
        openPairs()
        XCTAssertTrue(app.navigationBars["Pair cancellation"].waitForExistence(timeout: 10))
        app.terminate()
        try store.refundTransaction(identifier: transaction.identifier)
        app.launch()
        openPairs()
        XCTAssertTrue(app.buttons["paywall.purchase"].waitForExistence(timeout: 10))
    }
    private func openPairs() {
        let pairs = app.buttons["drill-pairs"]
        XCTAssertTrue(pairs.waitForExistence(timeout: 10))
        for _ in 0..<6 where !pairs.isHittable { app.swipeUp() }
        pairs.tap()
    }
}
