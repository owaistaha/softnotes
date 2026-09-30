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
        // DEBUG main-thread watchdog: stalls > 500 ms go to os_log
        // (com.owaistaha.softnotes / watchdog) — see CLAUDE.md.
        app.launchArguments = ["-watchdog"]
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

    /// The write step auto-focuses and hides the nav while typing; press
    /// Done (Return) so Back / × are reachable again.
    private func leaveTextFieldIfFocused() {
        guard app.keyboards.firstMatch.waitForExistence(timeout: 2) else { return }
        app.descendants(matching: .any)["noteText"].typeText("\n")
        _ = app.buttons["composeBack"].waitForExistence(timeout: 2)
        Thread.sleep(forTimeInterval: 0.5)
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

    /// Step 3: open the picker, pick a different icon, go Next to step 2, Back to step 1.
    func testPickIconThenNext() {
        app.buttons["primaryAction"].tap()
        XCTAssertTrue(app.buttons["composeClose"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["iconCell_4"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.8)
        snap("10_picker_default")

        // Default selection is the blue sun (index 4).
        XCTAssertTrue(app.buttons["iconCell_4"].isSelected, "default selection should be cell 4")

        // Pick a different icon: the ring should glide, the preview should swap.
        app.buttons["iconCell_1"].tap()
        captureSequence("11_pick_pink")
        XCTAssertTrue(app.buttons["iconCell_1"].isSelected)
        XCTAssertFalse(app.buttons["iconCell_4"].isSelected)
        Thread.sleep(forTimeInterval: 0.5)
        snap("12_picker_pink_settled")

        // Next → step 2 (placeholder).
        app.buttons["primaryAction"].tap()
        captureSequence("13_next")
        XCTAssertTrue(app.staticTexts["Step 2 of 2"].waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 0.5)
        snap("14_step2_settled")

        // Back → step 1, selection preserved.
        leaveTextFieldIfFocused()
        app.buttons["composeBack"].tap()
        captureSequence("15_back")
        XCTAssertTrue(app.staticTexts["Step 1 of 2"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["iconCell_1"].isSelected, "selection should survive Back")

        // Back on step 1 closes the flow.
        app.buttons["composeBack"].tap()
        XCTAssertTrue(app.buttons["primaryAction"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["composeClose"].exists, "flow should be closed")
    }

    /// × always cancels, even from step 2; a new session starts fresh on step 1 with the default icon.
    func testCloseCancelsAndDraftResets() {
        app.buttons["primaryAction"].tap()
        XCTAssertTrue(app.buttons["iconCell_4"].waitForExistence(timeout: 5))
        app.buttons["iconCell_7"].tap()
        app.buttons["primaryAction"].tap()
        XCTAssertTrue(app.staticTexts["Step 2 of 2"].waitForExistence(timeout: 3))
        leaveTextFieldIfFocused()
        app.buttons["composeClose"].tap()
        XCTAssertTrue(app.buttons["primaryAction"].waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 0.8)

        app.buttons["primaryAction"].tap()
        XCTAssertTrue(app.staticTexts["Step 1 of 2"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["iconCell_4"].isSelected, "fresh draft should select the default icon")
    }

    /// No screenshots (they perturb timing): just performs the taps at known
    /// pauses so `VIDEO=1 scripts/ui-shots.sh testMotionForVideo` can record
    /// the simulator screen and frames can be extracted at 60 fps.
    func testMotionForVideo() {
        Thread.sleep(forTimeInterval: 1.5)
        app.buttons["primaryAction"].tap()                     // + → Next
        XCTAssertTrue(app.buttons["composeClose"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 2.0)
        app.buttons["composeClose"].tap()                      // Next → +
        XCTAssertTrue(app.buttons["primaryAction"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 2.0)
        app.buttons["primaryAction"].tap()
        XCTAssertTrue(app.buttons["iconCell_1"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 2.0)
        app.buttons["iconCell_1"].tap()                        // ring glides, preview swaps
        Thread.sleep(forTimeInterval: 2.0)
        app.buttons["primaryAction"].tap()                     // step 1 → 2
        Thread.sleep(forTimeInterval: 2.0)
        leaveTextFieldIfFocused()
        app.buttons["composeBack"].tap()                       // step 2 → 1
        Thread.sleep(forTimeInterval: 2.0)
    }

    /// DEBUG launch argument `-demoSave`: Next on the write step files a demo
    /// note (with the icon picked in step 1), and Home shows it.
    func testDemoSaveLaunchArgument() {
        app.terminate()
        app.launchArguments = ["-demoSave"]
        app.launch()
        XCTAssertTrue(app.buttons["primaryAction"].waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 1.0)

        app.buttons["primaryAction"].tap()
        XCTAssertTrue(app.buttons["iconCell_2"].waitForExistence(timeout: 5))
        app.buttons["iconCell_2"].tap()
        app.buttons["primaryAction"].tap()                       // → step 2
        XCTAssertTrue(app.staticTexts["Step 2 of 2"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["primaryAction"].isEnabled, "-demoSave should enable Next on the write step")
        app.buttons["primaryAction"].tap()                       // → demo save
        XCTAssertTrue(app.staticTexts["Have a good day"].waitForExistence(timeout: 10), "demo note should appear in Recent")
        Thread.sleep(forTimeInterval: 1.5)
        snap("20_demo_saved_home")
    }

    /// Without `-demoSave`, Next on the (empty) write step is disabled.
    func testNextDisabledOnEmptyWriteStep() {
        app.buttons["primaryAction"].tap()
        XCTAssertTrue(app.buttons["iconCell_0"].waitForExistence(timeout: 5))
        app.buttons["primaryAction"].tap()
        XCTAssertTrue(app.staticTexts["Step 2 of 2"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["primaryAction"].isEnabled, "Next must be disabled while the note is empty")
    }

    // MARK: - Step 4 (write)

    private var noteText: XCUIElement { app.descendants(matching: .any)["noteText"] }

    private func openWriteStep(pickIcon index: Int? = nil) {
        app.buttons["primaryAction"].tap()
        XCTAssertTrue(app.buttons["iconCell_0"].waitForExistence(timeout: 5))
        if let index { app.buttons["iconCell_\(index)"].tap() }
        app.buttons["primaryAction"].tap()
        XCTAssertTrue(app.staticTexts["Step 2 of 2"].waitForExistence(timeout: 3))
    }

    private func element(labelContaining parts: [String]) -> XCUIElement {
        let format = parts.map { _ in "label CONTAINS %@" }.joined(separator: " AND ")
        return app.descendants(matching: .any).matching(NSPredicate(format: format, argumentArray: parts)).firstMatch
    }

    /// Type a note on the software keyboard, Next → it lands on Home.
    func testWriteAndSave() {
        XCTAssertTrue(element(labelContaining: ["8 notes"]).exists, "Home should start with 8 notes")
        openWriteStep()
        snap("30_write_rest")

        // Auto-focus: the software keyboard appears without a tap.
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3),
                      "software keyboard should appear (hardware keyboard must be disconnected)")
        Thread.sleep(forTimeInterval: 0.6)
        snap("31_write_focused")
        XCTAssertFalse(app.buttons["primaryAction"].isEnabled, "Next disabled while empty")

        noteText.typeText("Have a good day")
        Thread.sleep(forTimeInterval: 0.4)
        snap("32_write_typed")
        XCTAssertTrue(app.buttons["primaryAction"].isEnabled)

        app.buttons["primaryAction"].tap()
        XCTAssertTrue(element(labelContaining: ["Have a good day", "Just now"]).waitForExistence(timeout: 10),
                      "new row should appear in Recent")
        XCTAssertTrue(element(labelContaining: ["9 notes"]).waitForExistence(timeout: 3), "count should go 8 → 9")
        Thread.sleep(forTimeInterval: 1.2)
        snap("33_home_after_save")
    }

    /// The tag chip cycles Daily → Work → Errands → Ideas → Daily.
    func testTagChipCycles() {
        openWriteStep()
        let chip = app.buttons["tagChip"]
        XCTAssertTrue(chip.waitForExistence(timeout: 3))
        for expected in ["Work", "Errands", "Ideas", "Daily"] {
            chip.tap()
            XCTAssertEqual(chip.label, "Tag: \(expected)")
        }
    }

    /// Text is capped at 48 characters and still fits the card's 4 lines.
    func testTextCapAndFit() {
        openWriteStep()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        let sentence = "Pick up the dry cleaning and call mum back about Sunday lunch plans ok"  // 70 chars
        // One key at a time (human pace); a single typeText burst outruns the
        // field's resync and isn't how people type.
        for character in sentence { noteText.typeText(String(character)) }
        Thread.sleep(forTimeInterval: 0.3)
        let value = (noteText.value as? String) ?? ""
        XCTAssertEqual(value.count, 48, "text should be capped at 48 characters, got \(value.count)")
        snap("40_cap_typical")

        // Worst case for width: wide capitals.
        noteText.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 48))
        for character in String(repeating: "WOW ", count: 13) { noteText.typeText(String(character)) }
        Thread.sleep(forTimeInterval: 0.3)
        XCTAssertEqual(((noteText.value as? String) ?? "").count, 48)
        snap("41_cap_wide")
    }

    /// Video only: keyboard rise, typing, save. `VIDEO=1 scripts/ui-shots.sh testWriteMotionForVideo`
    func testWriteMotionForVideo() {
        Thread.sleep(forTimeInterval: 1.0)
        openWriteStep()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 4))
        Thread.sleep(forTimeInterval: 1.0)
        for word in ["Have ", "a ", "good ", "day"] {
            noteText.typeText(word)
            Thread.sleep(forTimeInterval: 0.25)
        }
        Thread.sleep(forTimeInterval: 1.0)
        app.buttons["primaryAction"].tap()
        Thread.sleep(forTimeInterval: 2.5)
    }

    // MARK: - Step 6B (robustness)

    /// `-keyboardCycles 20`: the app opens the write step and focuses /
    /// dismisses the card 20 times with a main-thread watchdog running
    /// (DEBUG). Meanwhile this test polls the accessibility tree the way the
    /// write-step tests do (`keyboards.firstMatch`), which is what used to
    /// hang the app. Asserts no main-thread stall > 500 ms.
    func testKeyboardCyclesNoStalls() {
        relaunch(["-keyboardCycles", "20"])
        let report = app.descendants(matching: .any)["keyboardCycleReport"]
        let deadline = Date().addingTimeInterval(120)
        var polls = 0
        while !report.exists && Date() < deadline {
            _ = app.keyboards.firstMatch.exists
            polls += 1
            Thread.sleep(forTimeInterval: 0.25)
        }
        XCTAssertTrue(report.exists, "harness never finished")
        let summary = report.label
        let attachment = XCTAttachment(string: "\(summary) polls=\(polls)")
        attachment.name = "keyboard_cycles_report"
        attachment.lifetime = .keepAlways
        add(attachment)
        print("KEYBOARD CYCLES (under XCUITest, \(polls) polls): \(summary)")
        XCTAssertTrue(summary.contains("stalls=0 "), "main-thread stalls: \(summary)")
    }

    // MARK: - Step 5A (save + fold)

    private func relaunch(_ arguments: [String]) {
        app.terminate()
        app.launchArguments = arguments + ["-watchdog"]
        app.launch()
    }

    /// `-demoFold` raises and drops the software keyboard ≈2–3.5 s after
    /// launch. Polling the accessibility tree while the simulator's keyboard
    /// animates has hung the app until XCTest gives up ("Timed out while
    /// evaluating UI query" — also seen in Step 4), so don't query until the
    /// keyboard is gone. The save runs ≈3.2 → 8.7 s after launch.
    private func waitOutDemoKeyboard() {
        Thread.sleep(forTimeInterval: 4.0)
    }

    /// `-demoFold`: compose opens on the write step with "Have a good day"
    /// typed, the keyboard comes up, and the whole save runs by itself
    /// (≈3.2 s after launch): settle, lift, fold, push, drop, landing, toggle,
    /// zoom-out, row entry. Record it: `VIDEO=1 scripts/ui-shots.sh testDemoFold`.
    func testDemoFold() {
        relaunch(["-demoFold"])
        waitOutDemoKeyboard()
        waitForSaveToFinish()
        assertFiled(count: 9)
        snap("50_demo_fold_home")
    }

    /// Two saves in a row: the second one (via `-demoSave`, a circle icon)
    /// runs the same sequence and files note 10.
    func testSaveTwiceInARow() {
        relaunch(["-demoFold", "-demoSave"])
        waitOutDemoKeyboard()
        waitForSaveToFinish()
        assertFiled(count: 9)

        app.buttons["primaryAction"].tap()
        XCTAssertTrue(app.buttons["iconCell_0"].waitForExistence(timeout: 5))
        app.buttons["iconCell_0"].tap()                          // a circle icon
        app.buttons["primaryAction"].tap()                       // → write
        XCTAssertTrue(app.staticTexts["Step 2 of 2"].waitForExistence(timeout: 3))
        app.buttons["primaryAction"].tap()                       // → demo save
        waitForSaveToFinish()
        assertFiled(count: 10)
        snap("52_second_save_home")
    }

    /// Backgrounding mid-flight fast-forwards to the end state: the note is
    /// added exactly once, nothing is left in flight.
    func testBackgroundMidFlight() {
        relaunch(["-demoFold"])
        waitOutDemoKeyboard()                                    // save is ≈0.8 s in
        XCTAssertTrue(saveInFlight.exists, "save should be in flight")
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 1.5)
        app.activate()
        XCTAssertTrue(app.otherElements["folder"].waitForExistence(timeout: 5))
        // The end state renders on the first frame back.
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: saveInFlight)
        wait(for: [gone], timeout: 2)
        assertFiled(count: 9)
    }

    /// Reduce Motion (`-reduceMotion`, DEBUG): no flight, no fold — compose
    /// cross-fades straight to Home with the note filed.
    func testReduceMotionSave() {
        relaunch(["-demoFold", "-reduceMotion"])
        waitOutDemoKeyboard()
        let row = app.buttons["recentRow_0"]
        let filed = expectation(for: NSPredicate(format: "label CONTAINS 'Have a good day'"), evaluatedWith: row)
        wait(for: [filed], timeout: 10)
        XCTAssertFalse(saveInFlight.exists, "Reduce Motion must not run the flight")
        XCTAssertEqual(app.otherElements["folder"].label, "Notes folder, 9 notes")
        snap("51_reduce_motion_home")
    }

    // MARK: - Save helpers (identifier queries — cheaper than label predicates)

    private var saveInFlight: XCUIElement { app.descendants(matching: .any)["saveInFlight"] }

    private func waitForSaveToFinish(timeout: TimeInterval = 15) {
        XCTAssertTrue(saveInFlight.waitForExistence(timeout: 4), "save should start")
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: saveInFlight)
        wait(for: [gone], timeout: timeout)
    }

    /// Count, closed folder / toggle on, new note on top of Recent.
    private func assertFiled(count: Int) {
        let folder = app.otherElements["folder"]
        XCTAssertTrue(folder.waitForExistence(timeout: 3))
        XCTAssertEqual(folder.label, "Notes folder, \(count) notes")
        XCTAssertEqual(folder.value as? String, "Closed", "folder should be closed")
        // The toggle has the toggle trait, so XCUITest sees a switch ("1" = on).
        let toggle = app.descendants(matching: .any)["folderToggle"]
        XCTAssertTrue(["On", "1"].contains(toggle.value as? String ?? ""),
                      "toggle should be on (value \(String(describing: toggle.value)))")
        XCTAssertTrue(app.buttons["recentRow_0"].label.contains("Have a good day"),
                      "new note should top Recent (got \(app.buttons["recentRow_0"].label))")
    }
}
