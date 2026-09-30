import XCTest

/// Screenshot-driven UI tests. They exist to *see* the app's motion: each test
/// taps through part of the flow and attaches screenshots taken at fixed
/// offsets after the tap. `scripts/ui-shots.sh` runs them and exports the
/// attachments to `build/shots/ui/`.
final class SoftNotesUITests: XCTestCase {

    /// Offsets (seconds after the tap returns) at which frames are captured.
    /// XCUIScreen screenshots take ~50–150 ms each, so the *actual* capture
    /// time is written into the attachment name (`…_t150_actual212ms`).
    private let offsets: [TimeInterval] = [0, 0.15, 0.30, 0.60]

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["primaryAction"].waitForExistence(timeout: 10), "Home FAB not found")
        // Let the launch settle (idle chip float, etc.) before the first tap.
        Thread.sleep(forTimeInterval: 1.0)
    }

    // MARK: - Helpers

    /// Captures a screenshot per offset, measured from `start`.
    private func captureSequence(_ prefix: String, from start: Date = Date()) {
        for offset in offsets {
            let wait = offset - Date().timeIntervalSince(start)
            if wait > 0 { Thread.sleep(forTimeInterval: wait) }
            let actual = Date().timeIntervalSince(start)
            let shot = XCUIScreen.main.screenshot()
            let attachment = XCTAttachment(screenshot: shot)
            attachment.name = "\(prefix)_t\(Int(offset * 1000))_actual\(Int(actual * 1000))ms"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    private func snap(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func tapAndCapture(_ element: XCUIElement, prefix: String) {
        element.tap()
        captureSequence(prefix)
    }

    // MARK: - Tests

    /// + → Next morph: tap the FAB, capture; tap close, capture.
    func testFabMorphOpenAndClose() {
        snap("00_home_before")

        tapAndCapture(app.buttons["primaryAction"], prefix: "01_open")
        Thread.sleep(forTimeInterval: 0.6)
        snap("02_compose_settled")

        tapAndCapture(app.buttons["composeClose"], prefix: "03_close")
        Thread.sleep(forTimeInterval: 0.6)
        snap("04_home_after")
    }
}
