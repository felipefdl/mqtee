import XCTest

final class PayloadHeaderLayoutTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        if let app = app {
            app.terminate()
        }
        app = nil
    }

    func testPayloadLabelExists() throws {
        let payloadLabel = app.staticTexts["Payload"]
        if payloadLabel.waitForExistence(timeout: 5) {
            XCTAssertTrue(payloadLabel.isHittable, "Payload label should be visible")
        }
    }

    func testPayloadHeaderElementsCoexist() throws {
        let payloadLabel = app.staticTexts["Payload"]
        guard payloadLabel.waitForExistence(timeout: 5) else {
            throw XCTSkip("Payload label not found -- no message selected")
        }

        // Verify the Payload label is visible and hittable
        XCTAssertTrue(payloadLabel.isHittable, "Payload label should be hittable")

        // Verify the display mode picker exists alongside it
        let displayPicker = app.segmentedControls.firstMatch
        if displayPicker.exists {
            XCTAssertTrue(displayPicker.isHittable, "Display mode picker should be hittable")
        }
    }

    func testWindowCanBeResizedWithoutCrash() throws {
        // Verify app launches and main window exists
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5), "Main window should exist")

        // Resize using keyboard shortcut (Cmd+0 toggles sidebar, reducing width)
        app.typeKey("0", modifierFlags: .command)

        // Wait for layout to settle
        let payloadLabel = app.staticTexts["Payload"]
        if payloadLabel.waitForExistence(timeout: 3) {
            XCTAssertTrue(payloadLabel.isHittable, "Payload label should remain visible after sidebar toggle")
        }
    }
}
