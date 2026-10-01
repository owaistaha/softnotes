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
        app.launchArguments = ["-watchdog", "-inMemoryStore"]
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
        // Auto-focus raises the keyboard ≈0.85 s in and Next rides up with it:
        // a tap on the moving button can miss (the flake before Step 7). Let it settle.
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.8)
        XCTAssertTrue(app.buttons["primaryAction"].isEnabled, "-demoSave should enable Next on the write step")
        app.buttons["primaryAction"].tap()                       // → demo save
        // The row is ONE accessibility element ("<title>, <time>") since 6B, so
        // wait on its label. The save takes ≈5.5 s and up to ≈12 s on a loaded
        // host (the old 10 s wait flaked 2 in 10 runs, before and after Step 7).
        let top = app.buttons["recentRow_0"]
        let arrived = expectation(for: NSPredicate(format: "label BEGINSWITH %@", "Have a good day, "),
                                  evaluatedWith: top)
        wait(for: [arrived], timeout: 25)
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

    /// Home on a short screen (iPhone SE): once a save makes Recent three
    /// rows, Home is taller than the screen and scrolls. A vertical drag that
    /// starts on the folder must scroll it like a drag anywhere else (it used
    /// to be swallowed by the folder's tilt). Control: the same drag starting
    /// on "Recent". Where Home fits (standard phones) neither scrolls.
    /// `SIM_NAME="iPhone SE (3rd generation)" SIM_OS=26.5 scripts/ui-shots.sh testFolderDragScrollsOnShortScreens`
    func testFolderDragScrollsOnShortScreens() {
        relaunch(["-demoFold"])
        waitOutDemoKeyboard()
        waitForSaveToFinish()
        Thread.sleep(forTimeInterval: 1.0)
        let folder = app.otherElements["folder"]
        let recent = app.staticTexts["Recent"]
        XCTAssertTrue(folder.waitForExistence(timeout: 5))

        func dragUp(from element: XCUIElement) -> CGFloat {
            let before = folder.frame.minY
            let start = element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            start.press(forDuration: 0.01, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -200)),
                        withVelocity: .default, thenHoldForDuration: 0.2)
            Thread.sleep(forTimeInterval: 0.8)
            return before - folder.frame.minY
        }
        func scrollBack() {
            let start = recent.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            start.press(forDuration: 0.01, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 400)),
                        withVelocity: .default, thenHoldForDuration: 0.2)
            Thread.sleep(forTimeInterval: 0.8)
        }

        let control = dragUp(from: recent)
        scrollBack()
        let fromFolder = dragUp(from: folder)
        snap("60_folder_drag_up")
        print("FOLDER DRAG: control scrolled \(control)pt, from the folder \(fromFolder)pt")
        if control > 20 {
            XCTAssertGreaterThan(fromFolder, control * 0.7, "a vertical drag on the folder should scroll Home too")
        } else {
            XCTAssertEqual(fromFolder, 0, accuracy: 1, "Home fits: nothing scrolls")
        }
    }

    /// Video only: slow drags on the folder, held — right, then down — to
    /// check the tilt (chips move with it: parallax = 0.9 × tilt).
    /// `VIDEO=1 scripts/ui-shots.sh testFolderTiltForVideo`
    func testFolderTiltForVideo() {
        let folder = app.otherElements["folder"]
        XCTAssertTrue(folder.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1.0)
        let centre = folder.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
        centre.press(forDuration: 0.05, thenDragTo: centre.withOffset(CGVector(dx: 150, dy: 0)),
                     withVelocity: .slow, thenHoldForDuration: 1.0)
        Thread.sleep(forTimeInterval: 1.5)
        centre.press(forDuration: 0.05, thenDragTo: centre.withOffset(CGVector(dx: 0, dy: 120)),
                     withVelocity: .slow, thenHoldForDuration: 1.0)
        Thread.sleep(forTimeInterval: 1.5)
    }

    /// VoiceOver: labels, traits and order on Home, the picker and the
    /// write step. (The "Note saved. N notes." announcement can't be
    /// observed from XCUITest; it is posted in RootContainerView.)
    func testAccessibilityLabels() {
        // Home
        XCTAssertEqual(app.otherElements["folder"].label, "Notes folder, 8 notes")
        let toggle = app.switches["folderToggle"]
        XCTAssertTrue(toggle.exists, "the Notes toggle should read as a switch")
        XCTAssertEqual(toggle.label, "Notes")
        XCTAssertTrue(app.buttons["Search notes"].exists)
        XCTAssertTrue(app.buttons["Home"].isSelected)
        XCTAssertTrue(app.buttons["Saved"].exists)
        XCTAssertEqual(app.buttons["primaryAction"].label, "New note")
        let row = app.buttons["recentRow_0"]
        XCTAssertTrue(row.exists)
        XCTAssertTrue(row.label.hasPrefix("Buy fresh cherries, "), "row reads '<title>, <time>': \(row.label)")
        snap("70_a11y_home")
        XCTAssertEqual(row.label.components(separatedBy: ", ").count, 2, "nothing else in the row label: \(row.label)")

        // Picker: 12 buttons, named, in reading order, the selected one marked.
        app.buttons["primaryAction"].tap()
        XCTAssertTrue(app.buttons["iconCell_11"].waitForExistence(timeout: 5))
        let cells = (0..<12).map { app.buttons["iconCell_\($0)"] }
        XCTAssertEqual(cells.map(\.label), ["Smiling face", "Basket", "Paper plane", "Flame",
                                             "Sun", "Cup and saucer", "Leaf", "Heart",
                                             "Water drop", "Book", "Walking person", "Star"])
        let frames = cells.map(\.frame)
        for i in 1..<12 {
            let a = frames[i - 1], b = frames[i]
            XCTAssertTrue(b.minY > a.minY + 1 || (abs(b.minY - a.minY) <= 1 && b.minX > a.minX),
                          "cell \(i) should follow cell \(i - 1) in reading order")
        }
        XCTAssertTrue(cells[4].isSelected)
        XCTAssertEqual(cells.filter(\.isSelected).count, 1)
        XCTAssertEqual(app.otherElements["iconPreview"].label, "Selected icon: Sun")
        XCTAssertEqual(app.buttons["primaryAction"].label, "Next")
        snap("71_a11y_picker")

        // Write step
        app.buttons["primaryAction"].tap()
        XCTAssertTrue(noteText.waitForExistence(timeout: 5))
        XCTAssertEqual(noteText.label, "Note")
        XCTAssertEqual(app.buttons["tagChip"].label, "Tag: Daily")
        Thread.sleep(forTimeInterval: 1.5)
        snap("72_a11y_write")
    }

    // MARK: - Step 5A (save + fold)

    private func relaunch(_ arguments: [String]) {
        app.terminate()
        app.launchArguments = arguments + ["-watchdog", "-inMemoryStore"]
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

    /// The whole flow with Reduce Motion on (`-reduceMotion`): tab switch
    /// (pill fades), + → picker (ring fades between cells, preview fades),
    /// write, save (cross-fade, no flight), note filed.
    func testReduceMotionFullFlow() {
        relaunch(["-reduceMotion"])
        XCTAssertTrue(app.buttons["primaryAction"].waitForExistence(timeout: 10))
        app.buttons["Saved"].tap()
        app.buttons["Home"].tap()
        XCTAssertTrue(app.buttons["Home"].isSelected)

        app.buttons["primaryAction"].tap()
        XCTAssertTrue(app.buttons["iconCell_2"].waitForExistence(timeout: 5))
        app.buttons["iconCell_2"].tap()
        XCTAssertTrue(app.buttons["iconCell_2"].isSelected)
        XCTAssertFalse(app.buttons["iconCell_4"].isSelected)
        snap("52_reduce_motion_picker")
        app.buttons["primaryAction"].tap()

        XCTAssertTrue(noteText.waitForExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        noteText.typeText("Have a good day")
        app.buttons["primaryAction"].tap()

        let row = app.buttons["recentRow_0"]
        let filed = expectation(for: NSPredicate(format: "label CONTAINS 'Have a good day'"), evaluatedWith: row)
        wait(for: [filed], timeout: 10)
        XCTAssertFalse(saveInFlight.exists, "Reduce Motion must not run the flight")
        XCTAssertEqual(app.otherElements["folder"].label, "Notes folder, 9 notes")
        snap("53_reduce_motion_filed")
    }

    // MARK: - Step 7 (notes persist between launches)
    //
    // These run against the REAL file (no -inMemoryStore) in the simulator's
    // app container; the first launch of each test passes -resetStore.

    private func launchOnDisk(_ arguments: [String] = []) {
        app.terminate()
        app.launchArguments = arguments + ["-watchdog"]
        app.launch()
        XCTAssertTrue(app.buttons["primaryAction"].waitForExistence(timeout: 10), "Home FAB not found")
        Thread.sleep(forTimeInterval: 1.0)
    }

    private var folderLabel: String { app.otherElements["folder"].label }

    /// Home → Saved tab.
    private func openSavedTab() {
        app.buttons["Saved"].tap()
        Thread.sleep(forTimeInterval: 0.8)
    }

    private func rowButton(_ title: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title + ", ")).firstMatch
    }

    private func contextMenu(on row: XCUIElement, choose item: String) {
        row.press(forDuration: 1.0)
        let button = app.buttons[item]
        XCTAssertTrue(button.waitForExistence(timeout: 3), "context menu item \(item)")
        button.tap()
        Thread.sleep(forTimeInterval: 0.8)
    }

    /// Write a note, save it, wait for the save to finish, KILL the app (no
    /// background flush: the debounced write must already have happened),
    /// relaunch: the note is on top of Recent and the count went up by one.
    func testSavedNoteSurvivesRelaunch() {
        launchOnDisk(["-resetStore"])
        XCTAssertEqual(folderLabel, "Notes folder, 8 notes")
        openWriteStep()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        noteText.typeText("Have a good day")
        app.buttons["primaryAction"].tap()
        waitForSaveToFinish()
        assertFiled(count: 9)
        Thread.sleep(forTimeInterval: 1.0)                  // > the 300 ms debounce
        app.terminate()

        launchOnDisk()
        XCTAssertEqual(folderLabel, "Notes folder, 9 notes", "the count must have gone up by one")
        let top = app.buttons["recentRow_0"]
        XCTAssertTrue(top.waitForExistence(timeout: 3))
        XCTAssertTrue(top.label.hasPrefix("Have a good day, "), "new note should still top Recent: \(top.label)")
        let copies = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Have a good day, "))
        // (Each row appears as a Button wrapping a same-framed Button — count distinct frames.)
        let frames = Set((0..<copies.count).map { "\(copies.element(boundBy: $0).frame)" })
        XCTAssertEqual(frames.count, 1, "exactly one copy on screen: \(frames)")
        snap("80_relaunch_after_save")

        // And once more: nothing is re-seeded or duplicated.
        launchOnDisk()
        XCTAssertEqual(folderLabel, "Notes folder, 9 notes")
    }

    /// Toggle Saved on a note, send the app home (scene → background flushes
    /// within the debounce window), kill it, relaunch: still saved.
    func testSavedToggleSurvivesRelaunch() {
        launchOnDisk(["-resetStore"])
        let cherries = rowButton("Buy fresh cherries")
        XCTAssertTrue(cherries.waitForExistence(timeout: 3))
        contextMenu(on: cherries, choose: "Save")
        openSavedTab()
        XCTAssertTrue(rowButton("Buy fresh cherries").exists, "it should be in Saved now")
        XCUIDevice.shared.press(.home)                      // flush on background, no waiting
        app.terminate()

        launchOnDisk()
        openSavedTab()
        XCTAssertTrue(rowButton("Buy fresh cherries").waitForExistence(timeout: 3), "still saved after relaunch")
        XCTAssertTrue(rowButton("Launch day checklist").exists, "the seeded saved notes are still there")
        snap("81_saved_after_relaunch")
    }

    /// Delete a note, relaunch: still deleted (and not re-seeded).
    func testDeletedNoteStaysDeleted() {
        launchOnDisk(["-resetStore"])
        let cherries = rowButton("Buy fresh cherries")
        XCTAssertTrue(cherries.waitForExistence(timeout: 3))
        contextMenu(on: cherries, choose: "Delete")
        XCTAssertFalse(rowButton("Buy fresh cherries").exists)
        XCTAssertEqual(folderLabel, "Notes folder, 7 notes")
        Thread.sleep(forTimeInterval: 1.0)
        app.terminate()

        launchOnDisk()
        XCTAssertEqual(folderLabel, "Notes folder, 7 notes")
        XCTAssertFalse(rowButton("Buy fresh cherries").exists, "the deleted note must not come back")
        snap("82_home_after_delete_relaunch")
    }

    /// Zero notes: no chips, sensible empty states on Home and Saved, and an
    /// empty list stays empty across launches (never re-seeded).
    func testEmptyStoreStaysEmpty() {
        launchOnDisk(["-resetStore", "-emptyStore"])
        XCTAssertEqual(folderLabel, "Notes folder, 0 notes")
        XCTAssertTrue(app.staticTexts["No notes yet. Tap + to write your first one."].exists)
        XCTAssertFalse(app.buttons["recentRow_0"].exists)
        snap("83_empty_home")
        openSavedTab()
        XCTAssertTrue(app.staticTexts["No saved notes"].exists)
        snap("84_empty_saved")
        app.terminate()

        launchOnDisk()
        XCTAssertEqual(folderLabel, "Notes folder, 0 notes", "an empty list must not be re-seeded")
    }

    /// The demo flows must not write the real file: a demo save in one launch
    /// leaves the next (real) launch at the seeded 8 notes.
    func testDemoFlowsDoNotTouchTheRealFile() {
        launchOnDisk(["-resetStore"])
        XCTAssertEqual(folderLabel, "Notes folder, 8 notes")
        // No UI queries until the demo's keyboard is gone (see waitOutDemoKeyboard):
        // launchOnDisk polls the tree, which made this test fail 2 of 3 full runs.
        app.terminate()
        app.launchArguments = ["-demoFold", "-watchdog"]
        app.launch()
        waitOutDemoKeyboard()
        waitForSaveToFinish()
        assertFiled(count: 9)
        Thread.sleep(forTimeInterval: 1.0)
        launchOnDisk()
        XCTAssertEqual(folderLabel, "Notes folder, 8 notes", "the demo note must not have been persisted")
    }

    /// The (unchanged) save sequence into an EMPTY store: no chips to shuffle,
    /// count 0 → 1, the note tops Recent, nothing left in flight.
    func testSaveIntoEmptyStore() {
        relaunch(["-emptyStore", "-demoFold"])
        waitOutDemoKeyboard()
        waitForSaveToFinish()
        XCTAssertEqual(folderLabel, "Notes folder, 1 note")
        XCTAssertTrue(app.buttons["recentRow_0"].label.hasPrefix("Have a good day, "))
        Thread.sleep(forTimeInterval: 1.0)
        snap("85_first_note_into_empty_store")
    }

    // MARK: - Step 8 (note detail / edit)

    private var detailText: XCUIElement { app.descendants(matching: .any)["detailText"] }

    /// Taps a Recent row and waits for the overlay to settle (controls respond).
    private func openDetail(row index: Int = 0) {
        let row = app.buttons["recentRow_\(index)"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.buttons["detailBack"].waitForExistence(timeout: 5), "detail should open")
        XCTAssertTrue(detailText.waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 1.0)                   // the grow takes ≈0.6 s
    }

    private func closeDetail() {
        app.buttons["detailBack"].tap()
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.buttons["detailBack"])
        wait(for: [gone], timeout: 5)
        Thread.sleep(forTimeInterval: 0.4)
    }

    /// Focus the text, delete what is there, type `text`, press Return.
    private func replaceDetailText(with text: String) {
        // Tap the field's CENTRE: its frame is the bounding box of the −3° card, and
        // XCUITest's element tap aims near the box's top-left corner — outside the
        // tilted field, in the gap under the card icon (which then gets the tap).
        detailText.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        Thread.sleep(forTimeInterval: 1.0)
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.7)
        // The centre tap can leave the caret mid-text: delete, and if text remains
        // after the caret, tap again (now past the end) and delete the rest.
        for _ in 0..<3 {
            detailText.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 60))
            let left = (detailText.value as? String) ?? ""
            if left.isEmpty || left == "Tap to write..." { break }
            detailText.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            Thread.sleep(forTimeInterval: 0.3)
        }
        if !text.isEmpty { detailText.typeText(text) }
        snap("99_detail_typing")
        detailText.typeText("\n")
        Thread.sleep(forTimeInterval: 0.7)
    }

    func testDetailOpensShowsTheNoteAndCloses() {
        openDetail()
        XCTAssertEqual(detailText.value as? String, "Buy fresh cherries")
        XCTAssertEqual(app.buttons["cardIcon"].label, "Icon: Basket")
        XCTAssertEqual(app.buttons["tagChip"].label, "Tag: Errands")
        XCTAssertTrue(app.staticTexts["Note"].exists)
        snap("90_detail_open")
        closeDetail()
        XCTAssertEqual(app.otherElements["folder"].label, "Notes folder, 8 notes")
        XCTAssertTrue(app.buttons["recentRow_0"].label.hasPrefix("Buy fresh cherries, "))
        snap("91_detail_closed")
    }

    /// Open → edit text → close → kill → relaunch shows the change.
    func testDetailEditTextSurvivesRelaunch() {
        launchOnDisk(["-resetStore"])
        openDetail()
        replaceDetailText(with: "Water the plants")
        snap("92_detail_edited")
        closeDetail()
        XCTAssertTrue(app.buttons["recentRow_0"].label.hasPrefix("Water the plants, "), app.buttons["recentRow_0"].label)
        Thread.sleep(forTimeInterval: 1.0)
        app.terminate()
        launchOnDisk()
        XCTAssertTrue(app.buttons["recentRow_0"].label.hasPrefix("Water the plants, "), "edit must survive a relaunch")
        XCTAssertEqual(app.otherElements["folder"].label, "Notes folder, 8 notes", "editing never adds or removes notes")
    }

    /// Leaving the text empty discards the edit; the note is NOT deleted.
    func testDetailEmptyTextRestoresTheOldText() {
        openDetail()
        replaceDetailText(with: "")
        XCTAssertEqual(detailText.value as? String, "Buy fresh cherries", "the old text comes back")
        closeDetail()
        XCTAssertTrue(app.buttons["recentRow_0"].label.hasPrefix("Buy fresh cherries, "))
        XCTAssertEqual(app.otherElements["folder"].label, "Notes folder, 8 notes")
    }

    func testDetailTextCapIs48() {
        openDetail()
        replaceDetailText(with: String(repeating: "ab ", count: 30))
        XCTAssertLessThanOrEqual((detailText.value as? String ?? "").count, 48)
    }

    func testDetailChangeIconSurvivesRelaunch() {
        launchOnDisk(["-resetStore"])
        openDetail()
        app.buttons["cardIcon"].tap()
        XCTAssertTrue(app.buttons["iconCell_5"].waitForExistence(timeout: 5), "picker grid should open")
        Thread.sleep(forTimeInterval: 0.6)
        snap("93_detail_picker")
        app.buttons["iconCell_5"].tap()
        Thread.sleep(forTimeInterval: 0.6)
        app.buttons["detailBack"].tap()                      // back to the card
        XCTAssertTrue(app.buttons["cardIcon"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["cardIcon"].label, "Icon: Cup and saucer")
        closeDetail()
        Thread.sleep(forTimeInterval: 1.0)
        app.terminate()
        launchOnDisk()
        openDetail()
        XCTAssertEqual(app.buttons["cardIcon"].label, "Icon: Cup and saucer", "icon change must survive a relaunch")
    }

    func testDetailTagChipCyclesAndPersists() {
        launchOnDisk(["-resetStore"])
        openDetail()
        XCTAssertEqual(app.buttons["tagChip"].label, "Tag: Errands")
        app.buttons["tagChip"].tap()
        XCTAssertEqual(app.buttons["tagChip"].label, "Tag: Ideas")
        closeDetail()
        Thread.sleep(forTimeInterval: 1.0)
        app.terminate()
        launchOnDisk()
        openDetail()
        XCTAssertEqual(app.buttons["tagChip"].label, "Tag: Ideas")
    }

    /// Heart toggles Saved (a switch for VoiceOver); persists; the note shows on the Saved tab.
    func testDetailToggleSaved() {
        launchOnDisk(["-resetStore"])
        openDetail()
        let heart = app.switches["detailSave"]
        XCTAssertTrue(heart.waitForExistence(timeout: 3), "the heart reads as a switch")
        XCTAssertEqual(heart.value as? String, "Off")
        heart.tap()
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertEqual(heart.value as? String, "On")
        closeDetail()
        openSavedTab()
        XCTAssertTrue(rowButton("Buy fresh cherries").waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 1.0)
        app.terminate()
        launchOnDisk()
        openSavedTab()
        XCTAssertTrue(rowButton("Buy fresh cherries").waitForExistence(timeout: 3), "still saved")
        // Open it from Saved and unsave: the row leaves the list, the overlay cross-fades closed.
        rowButton("Buy fresh cherries").tap()
        XCTAssertTrue(app.buttons["detailBack"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1.0)
        app.switches["detailSave"].tap()
        Thread.sleep(forTimeInterval: 0.5)
        closeDetail()
        XCTAssertFalse(rowButton("Buy fresh cherries").exists, "unsaved notes leave Saved")
    }

    func testDetailDeleteWithConfirmation() {
        launchOnDisk(["-resetStore"])
        openDetail()
        app.buttons["detailDelete"].tap()
        let confirm = app.buttons["Delete note"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 3), "a confirmation should appear")
        snap("94_detail_delete_confirm")
        confirm.tap()
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.buttons["detailBack"])
        wait(for: [gone], timeout: 6)
        Thread.sleep(forTimeInterval: 0.8)
        XCTAssertFalse(rowButton("Buy fresh cherries").exists)
        XCTAssertEqual(app.otherElements["folder"].label, "Notes folder, 7 notes")
        Thread.sleep(forTimeInterval: 1.0)
        app.terminate()
        launchOnDisk()
        XCTAssertEqual(app.otherElements["folder"].label, "Notes folder, 7 notes", "deleted for good")
    }

    func testDetailCancelDeleteKeepsTheNote() {
        openDetail()
        app.buttons["detailDelete"].tap()
        XCTAssertTrue(app.buttons["Delete note"].waitForExistence(timeout: 3))
        // iOS 17 shows a Cancel button; iOS 26 presents the dialog as a popover
        // that is dismissed by tapping outside it.
        if app.buttons["Cancel"].exists {
            app.buttons["Cancel"].tap()
        } else {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.92)).tap()
        }
        Thread.sleep(forTimeInterval: 0.6)
        XCTAssertTrue(app.buttons["detailBack"].exists, "still in the detail")
        XCTAssertEqual(detailText.value as? String, "Buy fresh cherries")
        closeDetail()
        XCTAssertEqual(app.otherElements["folder"].label, "Notes folder, 8 notes")
        XCTAssertTrue(app.buttons["recentRow_0"].label.hasPrefix("Buy fresh cherries, "))
    }

    /// Reduce Motion: the same flow with a cross-fade (no flight).
    func testDetailReduceMotionFlow() {
        relaunch(["-reduceMotion"])
        XCTAssertTrue(app.buttons["primaryAction"].waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 1.0)
        openDetail()
        snap("95_detail_reduce_motion")
        replaceDetailText(with: "Fade test")
        app.buttons["tagChip"].tap()
        closeDetail()
        XCTAssertTrue(app.buttons["recentRow_0"].label.hasPrefix("Fade test, "))
        openDetail()
        app.buttons["detailDelete"].tap()
        XCTAssertTrue(app.buttons["Delete note"].waitForExistence(timeout: 3))
        app.buttons["Delete note"].tap()
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.buttons["detailBack"])
        wait(for: [gone], timeout: 6)
        Thread.sleep(forTimeInterval: 0.8)
        XCTAssertEqual(app.otherElements["folder"].label, "Notes folder, 7 notes")
    }

    /// VoiceOver: labelled field, heart = switch, destructive delete hint, title element.
    func testDetailAccessibility() {
        openDetail()
        XCTAssertEqual(detailText.label, "Note text")
        XCTAssertEqual(app.switches["detailSave"].label, "Saved")
        XCTAssertTrue(app.buttons["detailDelete"].exists)
        // (XCUITest can't read accessibility hints: the delete / save / text-field hints are code-verified.)
        XCTAssertEqual(app.buttons["detailBack"].label, "Back")
        XCTAssertEqual(app.buttons["cardIcon"].label, "Icon: Basket")
        snap("96_detail_a11y")
    }

    /// 60 fps recording of open / close (+ editing and the picker):
    /// `VIDEO=1 scripts/ui-shots.sh testDetailMotionForVideo`.
    func testDetailMotionForVideo() {
        Thread.sleep(forTimeInterval: 1.0)
        for _ in 0..<2 {
            openDetail()
            Thread.sleep(forTimeInterval: 0.8)
            closeDetail()
            Thread.sleep(forTimeInterval: 0.8)
        }
        openDetail()
        detailText.tap()
        Thread.sleep(forTimeInterval: 1.4)
        detailText.typeText("\n")
        Thread.sleep(forTimeInterval: 0.8)
        app.buttons["cardIcon"].tap()
        Thread.sleep(forTimeInterval: 1.0)
        app.buttons["detailBack"].tap()
        Thread.sleep(forTimeInterval: 0.8)
        closeDetail()
        Thread.sleep(forTimeInterval: 0.8)
    }

    // MARK: - Step 9 (See all, Search)

    private func openAllNotes() {
        let seeAll = app.buttons["See all"]
        XCTAssertTrue(seeAll.waitForExistence(timeout: 5))
        seeAll.tap()
        XCTAssertTrue(app.buttons["allBack"].waitForExistence(timeout: 5), "All Notes should open")
        Thread.sleep(forTimeInterval: 1.0)
    }

    private func closeAllNotes() {
        app.buttons["allBack"].tap()
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.buttons["allBack"])
        wait(for: [gone], timeout: 5)
        Thread.sleep(forTimeInterval: 0.5)
    }

    /// Titles and ages (seconds) of `Note.samples`.
    private static let sampleAges: [(title: String, age: TimeInterval)] = [
        ("Buy fresh cherries", 2 * 3600), ("Launch day checklist", 26 * 3600), ("Book club picks", 4 * 86400),
        ("Water the monstera", 6 * 86400), ("Gift ideas for Mum", 9 * 86400), ("Morning pages", 12 * 86400),
        ("Run club route", 15 * 86400), ("Coffee beans to try", 21 * 86400),
    ]

    /// Expected group of a sample, worked out from calendar days (independently of NoteGroup).
    private func expectedGroup(age: TimeInterval) -> String {
        let cal = Calendar.current, now = Date(), date = now - age
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: date), to: cal.startOfDay(for: now)).day ?? 99
        if days <= 0 { return "Today" }
        if days == 1 { return "Yesterday" }
        return cal.isDate(date, equalTo: now, toGranularity: .weekOfYear) ? "This week" : "Earlier"
    }

    /// See all opens an All Notes screen with every note, grouped, newest first.
    func testSeeAllListsEverythingGrouped() {
        openAllNotes()
        snap("100_all_notes")
        XCTAssertTrue(app.staticTexts["All notes"].exists)
        // Every note is there.
        for (title, _) in Self.sampleAges { XCTAssertTrue(rowButton(title).exists, "\(title) should be listed") }
        // Group headers, in order, with the right rows under each.
        let order = ["Today", "Yesterday", "This week", "Earlier"]
        var expected: [String: [String]] = [:]
        for (title, age) in Self.sampleAges { expected[expectedGroup(age: age), default: []].append(title) }
        let headerElement = { (name: String) in self.app.staticTexts["allGroup_\(name)"] }
        let headers = order.filter { headerElement($0).exists }
        XCTAssertEqual(headers, order.filter { expected[$0] != nil }, "group headers present, in order")
        for (i, header) in headers.enumerated() {
            let top = headerElement(header).frame.minY
            let bottom = i + 1 < headers.count ? headerElement(headers[i + 1]).frame.minY : .greatestFiniteMagnitude
            let rows = Self.sampleAges.map(\.title).filter {
                let y = rowButton($0).frame.minY
                return y > top && y < bottom
            }
            XCTAssertEqual(rows, expected[header], "rows under \(header) (newest first)")
        }
        closeAllNotes()
        XCTAssertTrue(app.otherElements["folder"].exists, "back on Home")
    }

    /// Context menu: Save / Delete from All Notes; tapping a row opens the detail on top, closing returns here.
    func testAllNotesContextMenuAndDetail() {
        openAllNotes()
        contextMenu(on: rowButton("Buy fresh cherries"), choose: "Save")
        closeAllNotes()
        openSavedTab()
        XCTAssertTrue(rowButton("Buy fresh cherries").waitForExistence(timeout: 3), "saved from All Notes")
        app.buttons["Home"].tap()
        Thread.sleep(forTimeInterval: 0.6)
        openAllNotes()
        contextMenu(on: rowButton("Coffee beans to try"), choose: "Delete")
        XCTAssertFalse(rowButton("Coffee beans to try").exists)
        // Open a row → detail → back to All Notes.
        rowButton("Book club picks").tap()
        XCTAssertTrue(app.buttons["detailBack"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1.0)
        XCTAssertEqual(detailText.value as? String, "Book club picks")
        snap("101_all_notes_detail")
        closeDetail()
        XCTAssertTrue(app.buttons["allBack"].exists, "closing the detail returns to All Notes")
        closeAllNotes()
        XCTAssertEqual(app.otherElements["folder"].label, "Notes folder, 7 notes")
    }

    /// Open from All Notes, edit, close, relaunch: the edit persisted.
    func testAllNotesOpenEditRelaunch() {
        launchOnDisk(["-resetStore"])
        openAllNotes()
        rowButton("Water the monstera").tap()
        XCTAssertTrue(app.buttons["detailBack"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1.0)
        replaceDetailText(with: "Water the ferns")
        closeDetail()
        XCTAssertTrue(rowButton("Water the ferns").exists)
        Thread.sleep(forTimeInterval: 1.0)
        app.terminate()
        launchOnDisk()
        openAllNotes()
        XCTAssertTrue(rowButton("Water the ferns").waitForExistence(timeout: 3), "edit survives a relaunch")
        XCTAssertFalse(rowButton("Water the monstera").exists)
    }

    func testAllNotesEmptyState() {
        launchOnDisk(["-resetStore", "-emptyStore"])
        openAllNotes()
        XCTAssertTrue(app.staticTexts["No notes yet"].exists)
        snap("102_all_notes_empty")
        closeAllNotes()
    }

    // MARK: Search

    private var searchField: XCUIElement { app.descendants(matching: .any)["searchField"] }

    /// Opens search with the button of the screen that is showing; waits for the keyboard.
    private func openSearch(button id: String = "searchButton") {
        let button = app.buttons[id]
        XCTAssertTrue(button.waitForExistence(timeout: 5), "search button \(id)")
        button.tap()
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "search should open")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "the keyboard is up on open")
        Thread.sleep(forTimeInterval: 0.6)
    }

    private func closeSearch() {
        app.buttons["searchClose"].tap()
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: searchField)
        wait(for: [gone], timeout: 5)
        Thread.sleep(forTimeInterval: 0.5)
    }

    private func search(_ text: String) {
        app.buttons["searchClear"].tapIfExists()
        searchField.typeText(text)
        Thread.sleep(forTimeInterval: 0.5)
    }

    private var searchHeading: String { app.staticTexts["searchHeading"].label }

    func testSearchEmptyQueryShowsTheLastFewNotes() {
        openSearch()
        snap("110_search_open")
        XCTAssertEqual(searchHeading, "Recent")
        for title in ["Buy fresh cherries", "Launch day checklist", "Book club picks", "Water the monstera", "Gift ideas for Mum"] {
            XCTAssertTrue(rowButton(title).exists, "\(title) is among the last five")
        }
        XCTAssertFalse(rowButton("Morning pages").exists, "only the last five are shown")
        closeSearch()
        XCTAssertTrue(app.otherElements["folder"].exists, "closing returns to Home")
    }

    func testSearchFindsByTextByTagAndShowsNoResults() {
        openSearch()
        search("CHERRIES")                                  // case-insensitive
        XCTAssertEqual(searchHeading, "1 result")
        XCTAssertTrue(rowButton("Buy fresh cherries").exists)
        XCTAssertFalse(rowButton("Launch day checklist").exists)
        snap("111_search_text")

        search("monstéra")                                  // diacritic-insensitive
        XCTAssertTrue(rowButton("Water the monstera").waitForExistence(timeout: 3))

        search("#errands")                                  // by tag
        XCTAssertTrue(rowButton("Buy fresh cherries").waitForExistence(timeout: 3))
        XCTAssertTrue(rowButton("Buy fresh cherries").label.contains("tagged Errands"), rowButton("Buy fresh cherries").label)
        snap("112_search_tag")

        search("work")                                      // "Work" tag on the launch checklist
        XCTAssertTrue(rowButton("Launch day checklist").waitForExistence(timeout: 3))

        search("zzzz")
        XCTAssertTrue(app.descendants(matching: .any)["searchEmpty"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["No notes match “zzzz”"].exists)
        snap("113_search_no_results")

        app.buttons["searchClear"].tap()                    // clear → the last few again
        XCTAssertTrue(app.staticTexts["searchHeading"].waitForExistence(timeout: 3))
        XCTAssertEqual(searchHeading, "Recent")
        closeSearch()
    }

    /// From Saved only saved notes are searched.
    func testSearchFromSavedOnlySearchesSavedNotes() {
        openSavedTab()
        openSearch()
        XCTAssertEqual(searchField.label, "Search saved notes")
        search("launch")                                    // saved (seeded)
        XCTAssertTrue(rowButton("Launch day checklist").waitForExistence(timeout: 3))
        search("cherries")                                  // NOT saved
        XCTAssertTrue(app.descendants(matching: .any)["searchEmpty"].waitForExistence(timeout: 3))
        XCTAssertFalse(rowButton("Buy fresh cherries").exists)
        search("mum")                                       // saved (seeded)
        XCTAssertTrue(rowButton("Gift ideas for Mum").waitForExistence(timeout: 3))
        snap("114_search_saved")
        closeSearch()
        XCTAssertTrue(app.staticTexts["Saved"].exists, "closing returns to Saved")
    }

    /// Search → open a result → edit → close (back in search) → relaunch: the edit persisted.
    func testSearchOpenResultEditRelaunch() {
        launchOnDisk(["-resetStore"])
        openSearch()
        search("monstera")
        rowButton("Water the monstera").tap()
        XCTAssertTrue(app.buttons["detailBack"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1.0)
        XCTAssertEqual(detailText.value as? String, "Water the monstera")
        replaceDetailText(with: "Water the ferns")
        closeDetail()
        XCTAssertTrue(searchField.exists, "closing the detail returns to the search")
        XCTAssertTrue(app.descendants(matching: .any)["searchEmpty"].waitForExistence(timeout: 3),
                      "the edited note no longer matches 'monstera'")
        search("ferns")
        XCTAssertTrue(rowButton("Water the ferns").waitForExistence(timeout: 3))
        closeSearch()
        Thread.sleep(forTimeInterval: 1.0)
        app.terminate()
        launchOnDisk()
        openSearch()
        search("ferns")
        XCTAssertTrue(rowButton("Water the ferns").waitForExistence(timeout: 3), "edit survives a relaunch")
    }

    /// All Notes → search → close returns to All Notes; a result opens the detail.
    func testSearchFromAllNotesReturnsThere() {
        openAllNotes()
        openSearch(button: "allSearchButton")
        search("book")
        XCTAssertTrue(rowButton("Book club picks").waitForExistence(timeout: 3))
        closeSearch()
        XCTAssertTrue(app.buttons["allBack"].exists, "back on All Notes")
        closeAllNotes()
    }

    func testSearchReduceMotionFlow() {
        relaunch(["-reduceMotion"])
        XCTAssertTrue(app.buttons["primaryAction"].waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 1.0)
        openSearch()
        search("cherries")
        rowButton("Buy fresh cherries").tap()
        XCTAssertTrue(app.buttons["detailBack"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1.0)
        closeDetail()
        XCTAssertTrue(searchField.exists)
        closeSearch()
        snap("115_search_reduce_motion_closed")
    }

    /// VoiceOver: labelled field, clear button, close button, a result count.
    func testSearchAccessibility() {
        openSearch()
        XCTAssertEqual(searchField.label, "Search notes")
        search("cher")
        XCTAssertEqual(app.buttons["searchClear"].label, "Clear search")
        XCTAssertEqual(app.buttons["searchClose"].label, "Close search")
        XCTAssertEqual(searchHeading, "1 result")
        XCTAssertTrue(app.staticTexts["searchHeading"].exists)
        // (The "N notes found" announcement and the field hint can't be read from XCUITest: code-verified.)
    }

    /// The in-app harness (`-searchCycles`): 20 cycles of query change / keyboard down / up / clear
    /// with the watchdog, no XCUITest interaction meanwhile — zero stalls over 500 ms.
    func testSearchCyclesNoStalls() {
        relaunch(["-searchCycles", "20"])
        let report = app.descendants(matching: .any)["keyboardCycleReport"]
        let deadline = Date().addingTimeInterval(150)
        while !report.exists && Date() < deadline { Thread.sleep(forTimeInterval: 0.5) }
        XCTAssertTrue(report.exists, "harness never finished")
        let summary = report.label
        let attachment = XCTAttachment(string: summary)
        attachment.name = "search_cycles_report"
        attachment.lifetime = .keepAlways
        add(attachment)
        print("SEARCH CYCLES (under XCUITest): \(summary)")
        // The 20 cycles: no stall over 500 ms. (The first open is reported after the "|": the
        // first-ever focus is UIKit loading frameworks inside becomeFirstResponder.)
        XCTAssertTrue(summary.hasPrefix("cycles=20 stalls=0 "), "main-thread stalls: \(summary)")
    }

    /// Keyboard stress for `scripts/stall-stress.sh`: open / dismiss / re-focus / type, repeatedly.
    func testSearchKeyboardCycles() {
        openSearch()
        for i in 0..<8 {
            search(i % 2 == 0 ? "cher" : "boo")
            searchField.typeText("\n")                      // Search key → keyboard down
            XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
            searchField.tap()                               // back up
            XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
            Thread.sleep(forTimeInterval: 0.4)
        }
        closeSearch()
    }

    /// 60 fps recording of the Step 9 opens: See all (open / detail from a row / close),
    /// Search (open with keyboard / detail from a result / close):
    /// `VIDEO=1 scripts/ui-shots.sh testStep9MotionForVideo`.
    func testStep9MotionForVideo() {
        Thread.sleep(forTimeInterval: 1.0)
        // See all
        openAllNotes()
        Thread.sleep(forTimeInterval: 0.8)
        rowButton("Book club picks").tap()
        XCTAssertTrue(app.buttons["detailBack"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1.2)
        closeDetail()
        Thread.sleep(forTimeInterval: 0.8)
        closeAllNotes()
        Thread.sleep(forTimeInterval: 1.0)
        // Search
        openSearch()
        search("cher")
        Thread.sleep(forTimeInterval: 0.6)
        rowButton("Buy fresh cherries").tap()
        XCTAssertTrue(app.buttons["detailBack"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1.2)
        closeDetail()
        Thread.sleep(forTimeInterval: 0.8)
        closeSearch()
        Thread.sleep(forTimeInterval: 1.0)
    }

    // MARK: - Step 11 (Dynamic Type)

    /// Home, See all, detail, search, picker, write — at one text size (`-dynamicTypeSize`, DEBUG;
    /// nil = the system default). Screenshots `dt_<label>_<n>_<screen>`.
    private func captureDynamicTypeScreens(_ label: String, size: String?) {
        relaunch(size.map { ["-dynamicTypeSize", $0] } ?? [])
        XCTAssertTrue(app.buttons["primaryAction"].waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 1.5)
        snap("dt_\(label)_1_home")
        openAllNotes()
        snap("dt_\(label)_2_allnotes")
        closeAllNotes()
        openDetail()
        snap("dt_\(label)_3_detail")
        closeDetail()
        openSearch()
        snap("dt_\(label)_4_search")
        closeSearch()
        app.buttons["primaryAction"].tap()
        XCTAssertTrue(app.buttons["iconCell_0"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1.0)
        snap("dt_\(label)_5_picker")
        app.buttons["primaryAction"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1.2)
        snap("dt_\(label)_6_write")
    }

    func testDynamicTypeScreensDefault() { captureDynamicTypeScreens("default", size: nil) }
    func testDynamicTypeScreensXXL() { captureDynamicTypeScreens("xxl", size: "xxLarge") }
    func testDynamicTypeScreensAX3() { captureDynamicTypeScreens("ax3", size: "accessibility3") }
    func testDynamicTypeScreensAX5() { captureDynamicTypeScreens("ax5", size: "accessibility5") }

    /// At AX5 the 48-character cap still fits the (fixed-size) paper card: the note text
    /// grows with the setting but shrinks back (never below 24pt) to stay inside the text
    /// area — on the write card (capped at xxxLarge, like the save's card) and on the detail
    /// card (not capped). The field's frame must stay inside the card's text area.
    func testNoteTextFitsAtAccessibilitySizes() {
        relaunch(["-dynamicTypeSize", "accessibility5"])
        XCTAssertTrue(app.buttons["primaryAction"].waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 1.0)
        openWriteStep()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.6)
        for character in "Pick up the dry cleaning and call mum back about" { noteText.typeText(String(character)) }
        Thread.sleep(forTimeInterval: 0.4)
        XCTAssertEqual(((noteText.value as? String) ?? "").count, 48)
        // Text area: 150pt tall (+ the −1.5° / ×1.2 editing pose's bounding box).
        XCTAssertLessThanOrEqual(noteText.frame.height, 150 * 1.2 + 8, "write card text overflows: \(noteText.frame)")
        snap("120_ax5_write_typical")
        noteText.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 48))
        for character in String(repeating: "WOW ", count: 12) { noteText.typeText(String(character)) }
        Thread.sleep(forTimeInterval: 0.4)
        XCTAssertLessThanOrEqual(noteText.frame.height, 150 * 1.2 + 8, "write card text overflows: \(noteText.frame)")
        snap("121_ax5_write_wide")
        noteText.typeText("\n")
        Thread.sleep(forTimeInterval: 0.6)
        app.buttons["composeClose"].tap()
        Thread.sleep(forTimeInterval: 1.0)

        // Detail card (not capped).
        openDetail()
        replaceDetailText(with: "WOW WOW WOW WOW WOW WOW WOW WOW WOW WOW WOW WOW")
        XCTAssertLessThanOrEqual(detailText.frame.height, 150 + 12, "detail card text overflows: \(detailText.frame)")
        snap("122_ax5_detail_wide")
        replaceDetailText(with: "Buy cherries")
        snap("123_ax5_detail_short")
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

private extension XCUIElement {
    func tapIfExists() { if exists { tap() } }
}
