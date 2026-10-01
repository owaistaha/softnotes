import XCTest
@testable import SoftNotes

/// Step 7: notes survive launches. Everything runs against a temp directory,
/// an ephemeral UserDefaults suite, or the in-memory persistence — never the
/// app's real file.
@MainActor
final class NotePersistenceTests: XCTestCase {

    private var dir: URL!
    private var suite: String!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("softnotes-tests-\(UUID().uuidString)")
        suite = "softnotes.tests.\(UUID().uuidString)"
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
    }

    private func file() -> FileNotePersistence {
        FileNotePersistence(directory: dir, defaults: UserDefaults(suiteName: suite)!)
    }

    private func store(_ p: NotePersisting, debounce: Duration = .milliseconds(60)) -> NotesStore {
        NotesStore(persistence: p, debounce: debounce)
    }

    private func files() -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []).sorted()
    }

    private func sample(_ title: String, _ ago: TimeInterval = 0, saved: Bool = false) -> Note {
        Note(title: title, body: "body of \(title)",
             icon: NoteIcon(symbol: "sun.max", tone: .blue, shape: .circle),
             tags: ["Daily", "Work"], createdAt: Date(timeIntervalSince1970: 1_790_000_000 - ago + 0.123),
             isSaved: saved)
    }

    private func json(_ s: String) throws { 
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try s.write(to: dir.appendingPathComponent("notes.json"), atomically: true, encoding: .utf8)
    }

    // MARK: Format

    func testRoundTripKeepsEveryField() throws {
        let notes = [sample("One"), sample("Two", 100, saved: true)]
        let decoded = try NoteCodec.decode(try NoteCodec.encode(notes))
        XCTAssertEqual(decoded.skipped, 0)
        XCTAssertEqual(decoded.notes.count, notes.count)
        for (a, b) in zip(decoded.notes, notes) {
            XCTAssertEqual(a.createdAt.timeIntervalSince1970, b.createdAt.timeIntervalSince1970, accuracy: 0.001)
            var aligned = a; aligned.createdAt = b.createdAt     // dates are stored to the millisecond
            XCTAssertEqual(aligned, b)
        }
    }

    func testEnvelopeHasVersionAndISO8601Dates() throws {
        let text = String(decoding: try NoteCodec.encode([sample("One")]), as: UTF8.self)
        let object = try JSONSerialization.jsonObject(with: Data(text.utf8)) as! [String: Any]
        XCTAssertEqual(object["version"] as? Int, 1)
        let first = (object["notes"] as! [[String: Any]])[0]
        let date = first["createdAt"] as! String
        XCTAssertNotNil(date.range(of: #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$"#, options: .regularExpression), date)
    }

    func testDecodesDatesWithoutFractionalSeconds() throws {
        try json(#"{"version":1,"notes":[{"title":"A","createdAt":"2026-09-30T08:00:00Z"}]}"#)
        guard case .notes(let notes, _) = file().load() else { return XCTFail("should load") }
        XCTAssertEqual(notes.first?.createdAt, Date(timeIntervalSince1970: 1_790_755_200))
    }

    func testNewerVersionIsMovedAsideNotOverwritten() throws {
        try json(#"{"version":2,"notes":[]}"#)
        guard case .corrupt(let moved) = file().load() else { return XCTFail("version 2 should not load") }
        XCTAssertNotNil(moved)
        XCTAssertFalse(files().contains("notes.json"))
    }

    // MARK: Tolerant decoding

    func testBadSymbolBadToneAndOneCorruptNote() throws {
        try json("""
        {"version":1,"notes":[
          {"title":"Good","createdAt":"2026-09-30T08:00:00Z",
           "icon":{"symbol":"sun.max","tone":"blue","shape":"circle"}},
          {"title":"Bad symbol","createdAt":"2026-09-30T07:00:00Z",
           "icon":{"symbol":"definitely.not.a.symbol","tone":"blue","shape":"circle"}},
          {"title":"Bad tone","createdAt":"2026-09-30T06:00:00Z",
           "icon":{"symbol":"leaf","tone":"chartreuse","shape":"hexagon"}},
          {"createdAt":"2026-09-30T05:00:00Z"},
          "not even an object",
          {"title":"Bad date","createdAt":"yesterday-ish"},
          {"title":"Last","createdAt":"2026-09-30T04:00:00Z","isSaved":true}
        ]}
        """)
        let s = store(file())
        XCTAssertEqual(s.notes.map(\.title), ["Good", "Bad symbol", "Bad tone", "Last"])
        XCTAssertEqual(s.notes[1].icon.symbol, NoteIcon.fallbackSymbol)
        XCTAssertTrue(NoteIcon.isValidSymbol(NoteIcon.fallbackSymbol))
        XCTAssertEqual(s.notes[1].icon.tone, .blue)                 // the valid parts survive
        XCTAssertEqual(s.notes[2].icon.symbol, "leaf")
        XCTAssertEqual(s.notes[2].icon.tone, NoteIcon.fallbackTone)
        XCTAssertEqual(s.notes[2].icon.shape, .squircle)
        XCTAssertTrue(s.notes[3].isSaved)
        // The three dropped notes are not lost for good: the original is kept.
        XCTAssertTrue(files().contains { $0.hasPrefix("notes.partial-") }, "\(files())")
    }

    func testBackwardsCompatibleWithTheOldSynthesizedFormat() throws {
        // Extra / unknown keys are ignored.
        try json(#"{"version":1,"notes":[{"title":"A","createdAt":"2026-09-30T08:00:00Z","colour":"red"}],"extra":1}"#)
        XCTAssertEqual(store(file()).notes.map(\.title), ["A"])
    }

    // MARK: Corrupt file

    func testCorruptFileIsMovedAsideAndNeverReseeded() throws {
        try json("{ this is not json")
        let p = file()
        let s = store(p)
        XCTAssertTrue(s.notes.isEmpty, "starts empty, not with the samples")
        XCTAssertTrue(p.hasSeeded)
        let names = files()
        XCTAssertFalse(names.contains("notes.json"))
        let corrupt = try XCTUnwrap(names.first { $0.hasPrefix("notes.corrupt-") && $0.hasSuffix(".json") })
        XCTAssertEqual(try String(contentsOf: dir.appendingPathComponent(corrupt), encoding: .utf8), "{ this is not json")

        // Next launch: still empty (no file, but seeded flag set) and the backup is untouched.
        XCTAssertTrue(store(p).notes.isEmpty)
        XCTAssertTrue(files().contains(corrupt))

        // A new note creates a fresh notes.json next to it.
        s.add(sample("Fresh")); s.flush()
        XCTAssertEqual(store(p).notes.map(\.title), ["Fresh"])
        XCTAssertTrue(files().contains(corrupt))
    }

    // MARK: Seeding

    func testFirstLaunchSeedsAndWritesTheFile() {
        let p = file()
        let s = store(p)
        XCTAssertEqual(s.count, Note.samples.count)
        XCTAssertTrue(files().contains("notes.json"))
        XCTAssertTrue(p.hasSeeded)
    }

    func testEmptyListStaysEmptyAcrossLaunches() {
        let p = file()
        let first = store(p)
        for note in first.notes { first.delete(note.id) }
        first.flush()
        XCTAssertEqual(first.count, 0)
        XCTAssertEqual(store(p).count, 0, "an emptied store must not be re-seeded")
        // ... even if the file itself is gone.
        try? FileManager.default.removeItem(at: dir.appendingPathComponent("notes.json"))
        XCTAssertEqual(store(p).count, 0)
    }

    func testResetStoreForgetsEverything() {
        let p = file()
        _ = store(p)
        p.reset()
        XCTAssertFalse(files().contains("notes.json"))
        XCTAssertFalse(p.hasSeeded)
        XCTAssertEqual(store(p).count, Note.samples.count, "after a reset the next launch seeds again")
    }

    // MARK: Mutations persist

    func testAddToggleDeleteSurviveARelaunch() {
        let p = file()
        let s = store(p)
        let fresh = Note(title: "Fresh", icon: .defaultIcon, createdAt: .now + 10)
        s.add(fresh)
        let victim = s.notes[1]
        s.delete(victim.id)
        let toggled = s.notes[2]
        s.toggleSaved(toggled.id)
        s.flush()

        let again = store(p)
        XCTAssertEqual(again.notes.first?.id, fresh.id)
        XCTAssertFalse(again.notes.contains { $0.id == victim.id })
        XCTAssertEqual(again.notes.first { $0.id == toggled.id }?.isSaved, !toggled.isSaved)
        XCTAssertEqual(again.count, Note.samples.count)         // +1 added, −1 deleted
    }

    // MARK: Debounce and flush

    func testRapidChangesCollapseIntoOneWrite() async throws {
        let p = InMemoryNotePersistence(notes: [], hasSeeded: true)
        let s = store(p, debounce: .milliseconds(150))
        for i in 0..<6 { s.add(sample("n\(i)", Double(-i))) }
        s.toggleSaved(s.notes[0].id)
        s.delete(s.notes[5].id)
        XCTAssertEqual(p.saveCount, 0, "nothing is written synchronously")
        try await Task.sleep(for: .milliseconds(600))
        XCTAssertEqual(p.saveCount, 1)
        XCTAssertEqual(p.lastSaved?.count, 5)
    }

    func testSeparateBurstsWriteSeparately() async throws {
        let p = InMemoryNotePersistence(notes: [], hasSeeded: true)
        let s = store(p, debounce: .milliseconds(80))
        s.add(sample("a"))
        try await Task.sleep(for: .milliseconds(400))
        s.add(sample("b"))
        try await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(p.saveCount, 2)
    }

    func testFlushWritesNowAndTheDebounceDoesNotWriteAgain() async throws {
        let p = InMemoryNotePersistence(notes: [], hasSeeded: true)
        let s = store(p, debounce: .milliseconds(150))
        s.add(sample("landing"))
        s.flush()                                            // scene → background
        XCTAssertEqual(p.saveCount, 1, "flush is synchronous")
        s.flush()                                            // inactive, then background
        try await Task.sleep(for: .milliseconds(500))
        XCTAssertEqual(p.saveCount, 1, "the note is written exactly once")
    }

    func testFlushWithNothingPendingWritesNothing() {
        let p = InMemoryNotePersistence(notes: [sample("a")], hasSeeded: true)
        let s = store(p)
        s.flush()
        XCTAssertEqual(p.saveCount, 0)
        s.delete(UUID())                                     // no such note: not a change
        s.flush()
        XCTAssertEqual(p.saveCount, 0)
    }

    func testFailedWriteIsRetriedByTheNextFlush() {
        let p = InMemoryNotePersistence(notes: [], hasSeeded: true)
        let s = store(p)
        p.failsToSave = true
        s.add(sample("a")); s.flush()
        XCTAssertEqual(p.saveCount, 0)
        p.failsToSave = false
        // The failure marks the store dirty again (hop to main).
        let hop = expectation(description: "main hop"); DispatchQueue.main.async { hop.fulfill() }
        wait(for: [hop], timeout: 2)
        s.flush()
        XCTAssertEqual(p.saveCount, 1)
    }

    // MARK: Store behaviour with old notes

    func testRecentIgnoresNotesOlderThan48HoursAndCountIsTotal() {
        let day: TimeInterval = 86_400
        let s = NotesStore(notes: [
            Note(title: "now", icon: .defaultIcon, createdAt: .now - 60),
            Note(title: "47h", icon: .defaultIcon, createdAt: .now - 47 * 3600),
            Note(title: "49h", icon: .defaultIcon, createdAt: .now - 49 * 3600),
            Note(title: "old", icon: .defaultIcon, createdAt: .now - 30 * day),
        ])
        XCTAssertEqual(s.recent.map(\.title), ["now", "47h"])
        XCTAssertEqual(s.count, 4)
        XCTAssertEqual(s.folderPreview.count, 3)
        let none = NotesStore(notes: [])
        XCTAssertTrue(none.recent.isEmpty); XCTAssertTrue(none.folderPreview.isEmpty); XCTAssertEqual(none.count, 0)
    }

    func testEqualDatesKeepTheirFileOrder() throws {
        let when = Date(timeIntervalSince1970: 1_790_000_000)
        let notes = ["a", "b", "c", "d"].map { Note(title: $0, icon: .defaultIcon, createdAt: when) }
        let p = InMemoryNotePersistence(notes: notes, hasSeeded: true)
        XCTAssertEqual(store(p).notes.map(\.title), ["a", "b", "c", "d"])
    }

    // MARK: update (Step 8)

    func testUpdateEditsInPlaceAndPersistsOnce() async throws {
        let p = InMemoryNotePersistence(notes: [sample("a"), sample("b", 10)], hasSeeded: true)
        let s = store(p, debounce: .milliseconds(100))
        let id = s.notes[1].id
        s.update(id) { $0.title = "b1"; $0.body = "b1" }
        s.update(id) { $0.icon = NoteIcon(symbol: "leaf", tone: .green) }
        s.update(id) { $0.tags = ["Work"] }
        XCTAssertEqual(s.notes[1].title, "b1")
        XCTAssertEqual(s.notes.map(\.title), ["a", "b1"], "order is unchanged")
        XCTAssertEqual(p.saveCount, 0)
        try await Task.sleep(for: .milliseconds(500))
        XCTAssertEqual(p.saveCount, 1, "three quick edits, one write")
        XCTAssertEqual(p.lastSaved?[1].icon.symbol, "leaf")
    }

    func testUnchangedOrUnknownUpdateWritesNothing() {
        let p = InMemoryNotePersistence(notes: [sample("a")], hasSeeded: true)
        let s = store(p)
        s.update(s.notes[0].id) { $0.title = "a" }
        s.update(UUID()) { $0.title = "zzz" }
        s.flush()
        XCTAssertEqual(p.saveCount, 0)
    }

    func testEditDraftStartsFromTheNote() {
        let n = Note(title: "Water the monstera", icon: NoteIcon(symbol: "leaf", tone: .green),
                     tags: ["Errands"], createdAt: Date(timeIntervalSince1970: 1_790_000_000))
        let d = ComposeDraft(editing: n)
        XCTAssertEqual(d.text, "Water the monstera")
        XCTAssertEqual(d.tag, "Errands")
        XCTAssertEqual(d.icon, n.icon)
        XCTAssertEqual(d.createdAt, n.createdAt)
        XCTAssertEqual(ComposeDraft(editing: Note(title: "x", icon: .defaultIcon)).tag, "Daily")
    }
}
