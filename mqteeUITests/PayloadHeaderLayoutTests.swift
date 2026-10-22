#if os(macOS)
import XCTest

/// Verifies the payload pane header (title, content-type badge, display-mode picker) of a selected message
/// stays laid out correctly: present, left-to-right in order, not overlapping, and inside the window.
/// Runs against the mock session (`--screenshot-session`), so no broker is needed.
final class PayloadHeaderLayoutTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["--screenshot-mode", "--screenshot-session"]
        app.launch()
        try selectJSONMessage()
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    // MARK: - Tests

    func testPayloadHeaderElementsArePresentAndDoNotOverlap() {
        assertHeaderLayout("initial layout")
    }

    func testPayloadHeaderSurvivesSidebarCollapse() {
        setSidebar(visible: false)
        assertHeaderLayout("sidebar collapsed")

        setSidebar(visible: true)
        assertHeaderLayout("sidebar restored")
    }

    /// The window opens at its minimum width (1250 pt), the tightest layout the header must fit in.
    func testPayloadHeaderFitsAtMinimumWindowWidth() {
        let window = app.windows.firstMatch
        XCTAssertGreaterThanOrEqual(window.frame.width, 1250, "Window should honor its minimum width")
        assertHeaderLayout("minimum window width")

        setSidebar(visible: false)
        assertHeaderLayout("minimum window width, sidebar collapsed")
    }

    func testDisplayModePickerChangesMode() {
        let picker = element("payload.displayMode")
        XCTAssertTrue(picker.isHittable, "Display mode picker should be clickable")
        picker.click()
        let hex = app.menuItems["Hex"]
        XCTAssertTrue(hex.waitForExistence(timeout: 3), "Hex mode should be offered")
        hex.click()
        assertHeaderLayout("hex mode")
        let hexText = app.staticTexts.matching(NSPredicate(format: "value CONTAINS[c] '7B'")).firstMatch
        XCTAssertTrue(hexText.waitForExistence(timeout: 5), "Hex rendering of the JSON payload should appear")
    }

    // MARK: - Helpers

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func find(prefix: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@ OR value BEGINSWITH %@", prefix, prefix))
            .firstMatch
    }

    /// Selects the `homeassistant/sensor` topic, then a JSON message in its list.
    private func selectJSONMessage() throws {
        // Sidebar visibility is persisted across launches; a previous test may have left it hidden.
        if app.buttons["Show Sidebar"].waitForExistence(timeout: 3) {
            app.buttons["Show Sidebar"].click()
        }
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10), "Main window should exist")

        let root = find(prefix: "homeassistant/sensor")
        XCTAssertTrue(root.waitForExistence(timeout: 10), "Mock topic tree should load")
        root.click()

        let row = find(prefix: "homeassistant/sensor/living_room/temperature")
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Message rows should list the node's messages")
        row.click()

        XCTAssertTrue(
            element("payload.contentType").waitForExistence(timeout: 10),
            "Content-type badge should appear once a message is selected"
        )
    }

    /// Clicks the toolbar sidebar button and waits until the topic filter field appears or disappears.
    private func setSidebar(visible: Bool, file: StaticString = #filePath, line: UInt = #line) {
        let button = app.buttons[visible ? "Show Sidebar" : "Hide Sidebar"]
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Sidebar toolbar button missing", file: file, line: line)
        button.click()
        let filter = app.textFields["Filter topics..."]
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "hittable == %@", NSNumber(value: visible)),
            object: filter
        )
        XCTAssertEqual(
            XCTWaiter().wait(for: [expectation], timeout: 5),
            .completed,
            "Sidebar should be \(visible ? "shown" : "hidden")",
            file: file,
            line: line
        )
    }

    private func assertHeaderLayout(_ context: String, file: StaticString = #filePath, line: UInt = #line) {
        let window = app.windows.firstMatch.frame
        let title = element("payload.title")
        let badge = element("payload.contentType")
        let picker = element("payload.displayMode")

        for (name, item) in [("title", title), ("badge", badge), ("picker", picker)] {
            XCTAssertTrue(item.waitForExistence(timeout: 5), "\(name) missing (\(context))", file: file, line: line)
            XCTAssertTrue(item.isHittable, "\(name) not hittable (\(context))", file: file, line: line)
            XCTAssertFalse(item.frame.isEmpty, "\(name) empty frame (\(context))", file: file, line: line)
            XCTAssertTrue(
                window.contains(item.frame),
                "\(name) outside window (\(context)): \(item.frame) vs \(window)",
                file: file,
                line: line
            )
        }

        let (t, b, p) = (title.frame, badge.frame, picker.frame)
        XCTAssertLessThanOrEqual(t.maxX, b.minX, "Title overlaps badge (\(context))", file: file, line: line)
        XCTAssertLessThanOrEqual(b.maxX, p.minX, "Badge overlaps picker (\(context))", file: file, line: line)
        XCTAssertFalse(t.intersects(p), "Title overlaps picker (\(context))", file: file, line: line)
        let pickerDelta = abs(title.frame.midY - picker.frame.midY)
        XCTAssertLessThan(pickerDelta, 8, "Title/picker misaligned (\(context))", file: file, line: line)
        let badgeDelta = abs(title.frame.midY - badge.frame.midY)
        XCTAssertLessThan(badgeDelta, 8, "Title/badge misaligned (\(context))", file: file, line: line)
    }
}

#endif
