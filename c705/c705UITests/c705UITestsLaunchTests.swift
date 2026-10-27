//
//  c705UITestsLaunchTests.swift
//  c705UITests
//
//  Created by Avery Harris on 12/22/25.
//
//  PURPOSE: A test that launches the app and saves a screenshot of the launch
//  screen, so you can see what first appears.
//

import XCTest

final class c705UITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    // Starts the app and attaches a screenshot to the test results.
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
