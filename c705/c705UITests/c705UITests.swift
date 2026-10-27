//
//  c705UITests.swift
//  c705UITests
//
//  Created by Avery Harris on 12/22/25.
//
//  PURPOSE: Home for tests that launch the app and tap through it like a user.
//  It only holds Xcode's example checks (launch the app, time the
//  launch).
//

import XCTest

final class c705UITests: XCTestCase {

    // Runs before each test. continueAfterFailure = false stops a test at its first failure.
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    // Measures how long the app takes to start.
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
