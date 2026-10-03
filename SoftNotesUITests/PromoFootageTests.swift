import XCTest

/// Choreographed tours used ONLY to record promo footage — not part of the regular
/// suite's assertions. `scripts/promo-footage.sh` records the simulator screen around
/// each test and uses the `PROMO_MARK <name> <epoch>` lines these print to trim clips.
///
///   scripts/promo-footage.sh                   # every clip
///   scripts/promo-footage.sh testPromoCompose  # one clip
final class PromoFootageTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Helpers

    private func launch(_ extra: [String] = [], waitForHome: Bool = true) {
        app = XCUIApplication()
        app.launchArguments = ["-inMemoryStore"] + extra
        app.launch()
        // `-demoFold` raises the keyboard straight away: querying the tree then can hang the app.
        guard waitForHome else { return }
        XCTAssertTrue(app.buttons["primaryAction"].waitForExistence(timeout: 10), "Home FAB not found")
        Thread.sleep(forTimeInterval: 1.5)           // let the launch settle
    }

    /// Prints a wall-clock mark the recorder script turns into a video offset.
    private func mark(_ name: String) {
        NSLog("PROMO_MARK %@ %f", name, Date().timeIntervalSince1970)
    }

    private func pause(_ seconds: TimeInterval) { Thread.sleep(forTimeInterval: seconds) }

    private var noteText: XCUIElement { app.descendants(matching: .any)["noteText"] }
    private var detailText: XCUIElement { app.descendants(matching: .any)["detailText"] }
    private var searchField: XCUIElement { app.descendants(matching: .any)["searchField"] }
    private var saveInFlight: XCUIElement { app.descendants(matching: .any)["saveInFlight"] }

    private func waitUntilGone(_ element: XCUIElement, timeout: TimeInterval = 15) {
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: element)
        wait(for: [gone], timeout: timeout)
    }

    private func closeDetail() {
        app.buttons["detailBack"].tap()
        waitUntilGone(app.buttons["detailBack"], timeout: 6)
        pause(0.6)
    }

    private func openDetail(row index: Int = 0) {
        let row = app.buttons["recentRow_\(index)"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.buttons["detailBack"].waitForExistence(timeout: 5))
        XCTAssertTrue(detailText.waitForExistence(timeout: 3))
        pause(1.1)
    }

    private func typeSlowly(_ text: String, into element: XCUIElement, gap: TimeInterval = 0.07) {
        for ch in text {
            element.typeText(String(ch))
            pause(gap)
        }
    }

    // MARK: - Clips

    /// Home: folder tilt, chips, Recent, tab bar pill sliding Home → Saved → Home.
    func testPromoHome() {
        launch()
        let folder = app.otherElements["folder"]
        XCTAssertTrue(folder.waitForExistence(timeout: 5))
        mark("home_start")
        pause(2.0)
        mark("tilt")
        let centre = folder.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
        centre.press(forDuration: 0.05, thenDragTo: centre.withOffset(CGVector(dx: 140, dy: 0)),
                     withVelocity: .slow, thenHoldForDuration: 0.8)
        pause(1.0)
        centre.press(forDuration: 0.05, thenDragTo: centre.withOffset(CGVector(dx: -130, dy: 40)),
                     withVelocity: .slow, thenHoldForDuration: 0.6)
        pause(1.6)
        mark("tabs")
        app.buttons["Saved"].tap()
        pause(2.0)
        app.buttons["Home"].tap()
        pause(2.2)
        mark("home_end")
    }

    /// FAB → Next morph, picker ring glide, write a chit, tag cycling, save → fold → file away.
    func testPromoCompose() {
        launch()
        mark("compose_start")
        pause(1.0)
        mark("tap_plus")
        app.buttons["primaryAction"].tap()
        XCTAssertTrue(app.buttons["iconCell_0"].waitForExistence(timeout: 5))
        pause(1.8)
        mark("picker")
        for cell in [1, 6, 9, 2] {
            app.buttons["iconCell_\(cell)"].tap()
            pause(1.1)
        }
        mark("tap_next")
        app.buttons["primaryAction"].tap()
        XCTAssertTrue(app.staticTexts["Step 2 of 2"].waitForExistence(timeout: 3))
        mark("write")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 6))
        pause(1.2)
        mark("typing")
        typeSlowly("Sunday market run", into: noteText)
        pause(0.8)
        noteText.typeText("\n")                                    // Done → nav comes back
        XCTAssertTrue(app.buttons["composeBack"].waitForExistence(timeout: 3))
        pause(1.0)
        mark("tags")
        let chip = app.buttons["tagChip"]
        XCTAssertTrue(chip.waitForExistence(timeout: 3))
        chip.tap(); pause(0.9)
        chip.tap(); pause(0.9)
        chip.tap(); pause(0.9)                                     // Daily → Work → Errands → Ideas
        mark("save")
        app.buttons["primaryAction"].tap()
        XCTAssertTrue(saveInFlight.waitForExistence(timeout: 4), "save should start")
        waitUntilGone(saveInFlight, timeout: 20)
        mark("saved")
        pause(2.5)
        mark("compose_end")
    }

    /// Open a note from its row (the icon flies), change icon, heart it, edit text, delete.
    func testPromoDetail() {
        launch()
        mark("detail_start")
        pause(0.8)
        mark("open")
        openDetail(row: 0)
        pause(1.0)
        mark("icon")
        app.buttons["cardIcon"].tap()
        pause(1.2)
        app.buttons["iconCell_7"].tap()
        pause(1.0)
        app.buttons["iconCell_2"].tap()
        pause(1.0)
        app.buttons["detailBack"].tap()                           // back from the picker
        pause(1.0)
        mark("heart")
        let heart = app.switches["detailSave"]
        if heart.waitForExistence(timeout: 3) { heart.tap() }
        pause(1.4)
        mark("edit")
        detailText.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        pause(1.4)
        for _ in 0..<2 {
            detailText.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 40))
            let left = (detailText.value as? String) ?? ""
            if left.isEmpty || left == "Tap to write..." { break }
            detailText.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            pause(0.3)
        }
        typeSlowly("Cherries and figs", into: detailText)
        pause(0.6)
        detailText.typeText("\n")
        pause(1.2)
        mark("close")
        closeDetail()
        pause(1.0)
        mark("delete")
        openDetail(row: 1)
        app.buttons["detailDelete"].tap()
        let confirm = app.buttons["Delete note"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        pause(1.4)
        confirm.tap()
        waitUntilGone(app.buttons["detailBack"], timeout: 8)
        pause(1.8)
        mark("detail_end")
    }

    /// See all (grouped list + context menu), then Search by text.
    func testPromoAllAndSearch() {
        launch()
        mark("all_start")
        pause(0.8)
        let seeAll = app.buttons["See all"]
        XCTAssertTrue(seeAll.waitForExistence(timeout: 5))
        mark("open_all")
        seeAll.tap()
        XCTAssertTrue(app.buttons["allBack"].waitForExistence(timeout: 5))
        pause(2.0)
        app.swipeUp(velocity: .slow)
        pause(1.4)
        app.swipeDown(velocity: .slow)
        pause(1.0)
        mark("menu")
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Book club picks, ")).firstMatch
        if row.waitForExistence(timeout: 3) {
            row.press(forDuration: 1.0)
            pause(2.0)
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.97)).tap()   // dismiss the menu
            pause(1.2)
        }
        mark("close_all")
        app.buttons["allBack"].tap()
        pause(1.2)
        if app.buttons["allBack"].exists { app.buttons["allBack"].tap() }   // first tap may only have closed a menu
        waitUntilGone(app.buttons["allBack"], timeout: 6)
        pause(1.0)
        mark("open_search")
        app.buttons["searchButton"].tap()
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 6))
        pause(1.6)
        mark("typing")
        typeSlowly("cher", into: searchField, gap: 0.25)
        pause(1.8)
        mark("result")
        let hit = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Buy fresh cherries, ")).firstMatch
        if hit.waitForExistence(timeout: 3) {
            hit.tap()
            XCTAssertTrue(app.buttons["detailBack"].waitForExistence(timeout: 5))
            pause(1.6)
            closeDetail()
            pause(0.8)
        }
        app.buttons["searchClear"].tapIfExists()
        pause(0.6)
        typeSlowly("book", into: searchField, gap: 0.25)
        pause(1.6)
        mark("close_search")
        app.buttons["searchClose"].tap()
        waitUntilGone(searchField, timeout: 5)
        pause(1.4)
        mark("all_end")
    }

    /// Heart a note, then show it in the Saved tab.
    func testPromoSaved() {
        launch()
        mark("saved_start")
        openDetail(row: 0)
        let heart = app.switches["detailSave"]
        if heart.waitForExistence(timeout: 3) { heart.tap() }
        pause(1.2)
        closeDetail()
        pause(0.8)
        mark("saved_tab")
        app.buttons["Saved"].tap()
        pause(3.0)
        mark("saved_end")
    }

    /// Dynamic Type at an accessibility size: Home → detail → picker.
    func testPromoDynamicType() {
        launch(["-dynamicTypeSize", "accessibility2"])
        mark("dt_start")
        pause(2.2)
        app.swipeUp(velocity: .slow)
        pause(1.6)
        app.swipeDown(velocity: .slow)
        pause(1.0)
        mark("dt_detail")
        openDetail(row: 0)
        pause(2.0)
        closeDetail()
        mark("dt_end")
        pause(0.6)
    }

    /// The whole save with Reduce Motion on: fold becomes a cross-fade + count roll.
    func testPromoReduceMotion() {
        launch(["-reduceMotion", "-demoFold"], waitForHome: false)
        mark("rm_start")
        pause(15.0)        // the Reduce Motion save has no `saveInFlight` element; it runs ≈3–9 s after launch
        mark("rm_end")
    }

    /// The reference-faithful save (typed text, keyboard, fold) driven by the app itself.
    func testPromoDemoFold() {
        launch(["-demoFold"], waitForHome: false)
        mark("fold_start")
        pause(4.0)
        XCTAssertTrue(saveInFlight.waitForExistence(timeout: 10), "save should start")
        waitUntilGone(saveInFlight, timeout: 20)
        mark("fold_end")
        pause(2.0)
    }
}

private extension XCUIElement {
    func tapIfExists() { if exists { tap() } }
}
