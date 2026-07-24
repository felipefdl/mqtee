//
//  ScreenshotTests.swift
//  mqteeUITests
//
//  Captures App Store screenshots by navigating through the app in screenshot mode.
//  Tests that need a session view use --screenshot-session to auto-connect.
//

import XCTest

final class ScreenshotTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments.append("--screenshot-mode")
    }

    override func tearDownWithError() throws {
        if let app {
            app.terminate()
        }
        app = nil
    }

    // MARK: - Screenshot #0: Welcome (app logo / welcome view)

    func testWelcome() {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .phone {
            // iPhone: empty store shows full-screen logo overlay
            app.launchArguments.removeAll { $0 == "--screenshot-mode" }
        }
        #endif
        // --screenshot-welcome prevents auto-selecting a connection
        // iPad/Mac: mock data in sidebar + WelcomeView in detail pane
        // iPhone: empty store shows full-screen logo overlay
        app.launchArguments.append("--screenshot-welcome")
        launchApp()
        sleep(2)
        saveScreenshot(named: "00-welcome")
    }

    // MARK: - Screenshot #1: Command Center (connection list)

    func testCommandCenter() {
        launchApp()

        let firstConnection = app.staticTexts["Home Assistant"]
        XCTAssertTrue(firstConnection.waitForExistence(timeout: 10), "Mock connections should load")

        // On iPhone, auto-selected connection pushes detail view.
        // Tap back to reveal the connection list.
        let backButton = app.navigationBars.buttons.firstMatch
        if backButton.waitForExistence(timeout: 3) {
            backButton.tap()
            sleep(1)
        }

        saveScreenshot(named: "01-command-center")
    }

    // MARK: - Screenshot #2: Monitor Topics (session with topic tree)

    func testMonitorTopics() {
        app.launchArguments.append("--screenshot-session")
        launchApp()

        // Wait for session content to appear
        sleep(3)
        saveScreenshot(named: "02-monitor-topics")
    }

    // MARK: - Screenshot #3: Publish Precision (publish panel)

    func testPublishPrecision() {
        app.launchArguments.append("--screenshot-session")
        launchApp()
        sleep(2)

        // Open publish sheet/popover
        let publishButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'publish'")).firstMatch
        if publishButton.waitForExistence(timeout: 5) {
            publishButton.tap()
        }

        sleep(1)
        saveScreenshot(named: "03-publish-precision")
    }

    // MARK: - Screenshot #4: Enterprise Security (connection editor)

    func testEnterpriseSecurity() {
        launchApp()

        // Tap AWS IoT Core to see its detail
        let connection = app.staticTexts["AWS IoT Core"]
        if connection.waitForExistence(timeout: 10) {
            connection.tap()
            sleep(1)
        }

        // Tap Edit
        let editButton = app.navigationBars.buttons["Edit"].firstMatch
        if editButton.waitForExistence(timeout: 5) {
            editButton.tap()
            sleep(1)
        }

        // Tap Security tab
        let securityTab = app.buttons["Security"]
        if securityTab.waitForExistence(timeout: 3) {
            securityTab.tap()
            sleep(1)
        }

        saveScreenshot(named: "04-enterprise-security")
    }

    // MARK: - Screenshot #5: Debug Realtime (event log)

    func testDebugRealtime() {
        app.launchArguments.append("--screenshot-session")
        launchApp()
        sleep(2)

        // Tap the log status bar at the bottom to open log sheet
        let buttons = app.buttons.allElementsBoundByIndex
        for button in buttons.reversed() {
            if button.label.lowercased().contains("message") || button.label.lowercased().contains("connected") {
                button.tap()
                sleep(1)
                break
            }
        }

        saveScreenshot(named: "05-debug-realtime")
    }

    // MARK: - Screenshot #7: MQTT 5 Support (subscription sheet)

    func testMQTT5Support() {
        app.launchArguments.append("--screenshot-session")
        launchApp()
        sleep(2)

        // Tap the Subscriptions tab button
        let subscriptionsButton = app.buttons["Subscriptions"]
        if subscriptionsButton.waitForExistence(timeout: 5) {
            subscriptionsButton.tap()
            sleep(1)
        }

        saveScreenshot(named: "07-mqtt5-support")
    }

    // MARK: - Helpers

    private func launchApp() {
        app.launch()
    }

    private func saveScreenshot(named name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        writeScreenshotToRawFolder(screenshot, named: name)
    }

    private func writeScreenshotToRawFolder(_ screenshot: XCUIScreenshot, named name: String) {
        let fileURL = URL(fileURLWithPath: #filePath)
        let repoRoot = fileURL
            .deletingLastPathComponent() // mqteeUITests/
            .deletingLastPathComponent() // repo root

        #if os(iOS)
        let platform: String = UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "iphone"
        #else
        let platform: String = "mac"
        #endif

        let outputDir = repoRoot
            .appendingPathComponent("screenshots")
            .appendingPathComponent("raw")
            .appendingPathComponent(platform)

        do {
            try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
            let outputFile = outputDir.appendingPathComponent("\(name).png")
            try screenshot.pngRepresentation.write(to: outputFile, options: .atomic)
            print("Saved screenshot to \(outputFile.path)")
        } catch {
            XCTFail("Failed to write screenshot file for \(name): \(error)")
        }
    }
}
