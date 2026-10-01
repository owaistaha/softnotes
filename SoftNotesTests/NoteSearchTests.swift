import XCTest
@testable import SoftNotes

/// Step 9: grouping for All Notes, and search matching.
final class NoteSearchTests: XCTestCase {

    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        c.firstWeekday = 2                                  // Monday
        return c
    }()

    /// Thursday 1 Oct 2026, 12:00 UTC.
    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: 12))! }

    private func note(_ title: String, daysAgo: Double = 0, hoursAgo: Double = 0, tags: [String] = [],
                      saved: Bool = false, body: String = "") -> Note {
        Note(title: title, body: body, icon: .defaultIcon, tags: tags,
             createdAt: now - daysAgo * 86_400 - hoursAgo * 3600, isSaved: saved)
    }

    // MARK: Grouping

    func testGroupBoundaries() {
        let cases: [(Note, NoteGroup)] = [
            (note("now"), .today),
            (note("this morning", hoursAgo: 11), .today),                 // 01:00 today
            (note("late last night", hoursAgo: 13), .yesterday),          // 23:00 Wed
            (note("yesterday noon", daysAgo: 1), .yesterday),
            (note("monday", daysAgo: 3), .thisWeek),                      // Mon 28 Sep, same Mon–Sun week
            (note("sunday", daysAgo: 4), .earlier),                       // Sun 27 Sep = last week
            (note("old", daysAgo: 40), .earlier),
            (note("clock skew", hoursAgo: -2), .today),                   // slightly in the future
        ]
        for (n, expected) in cases {
            XCTAssertEqual(NoteGroup.of(n.createdAt, now: now, calendar: calendar), expected, n.title)
        }
    }

    func testGroupedOrderAndNewestFirstAndNoEmptyGroups() {
        let notes = [note("old", daysAgo: 20), note("today b", hoursAgo: 1), note("yesterday", daysAgo: 1),
                     note("today a", hoursAgo: 0.5), note("older", daysAgo: 30)]
        let grouped = NoteGroup.grouped(notes, now: now, calendar: calendar)
        XCTAssertEqual(grouped.map(\.group), [.today, .yesterday, .earlier])      // no "This week"
        XCTAssertEqual(grouped[0].notes.map(\.title), ["today a", "today b"])
        XCTAssertEqual(grouped[2].notes.map(\.title), ["old", "older"])
        XCTAssertTrue(NoteGroup.grouped([], now: now, calendar: calendar).isEmpty)
    }

    func testTheSampleDataGroupsSensibly() {
        // 2h ago, 26h ago, 4d, 6d, 9d, 12d, 15d, 21d — nothing crashes, everything lands somewhere.
        let grouped = NoteGroup.grouped(Note.samples)
        XCTAssertEqual(grouped.flatMap(\.notes).count, Note.samples.count)
    }

    // MARK: Matching

    func testMatchesTextCaseAndDiacriticInsensitively() {
        let n = note("Café Crème with Zoë")
        for q in ["cafe", "CAFE", "créme", "zoe", "ZOË", "crème with"] {
            XCTAssertTrue(NoteSearch.matches(n, query: q), q)
        }
        XCTAssertFalse(NoteSearch.matches(n, query: "tea"))
    }

    func testMatchesTagsWithOrWithoutHash() {
        let n = note("Buy cherries", tags: ["Errands"])
        XCTAssertTrue(NoteSearch.matches(n, query: "errands"))
        XCTAssertTrue(NoteSearch.matches(n, query: "#errands"))
        XCTAssertTrue(NoteSearch.matches(n, query: "#ERR"))
        XCTAssertFalse(NoteSearch.matches(n, query: "#work"))
    }

    func testEveryWordMustMatchSomewhere() {
        let n = note("Water the monstera", tags: ["Daily"])
        XCTAssertTrue(NoteSearch.matches(n, query: "water daily"))      // text + tag
        XCTAssertTrue(NoteSearch.matches(n, query: "  monstera   water "))
        XCTAssertFalse(NoteSearch.matches(n, query: "water work"))
    }

    func testBodyIsSearchedToo() {
        XCTAssertTrue(NoteSearch.matches(note("Title", body: "secret lemon"), query: "lemon"))
    }

    func testEmptyAndHashOnlyQueriesMatchEverythingButShowRecent() {
        let notes = (0..<8).map { note("n\($0)", hoursAgo: Double($0)) }
        XCTAssertTrue(NoteSearch.isEmpty("   "))
        XCTAssertTrue(NoteSearch.isEmpty("#"))
        let r = NoteSearch.results(in: notes, query: "  ")
        XCTAssertEqual(r.map(\.title), ["n0", "n1", "n2", "n3", "n4"])          // the last few, newest first
        XCTAssertEqual(NoteSearch.results(in: notes, query: "n").count, 8)
    }

    func testResultsAreNewestFirst() {
        let notes = [note("tea old", daysAgo: 5), note("tea new", hoursAgo: 1), note("coffee")]
        XCTAssertEqual(NoteSearch.results(in: notes, query: "tea").map(\.title), ["tea new", "tea old"])
    }

    func testNoResults() {
        XCTAssertTrue(NoteSearch.results(in: [note("a")], query: "zzz").isEmpty)
    }

    func testRangesForEmphasis() {
        let text = "Water the water plants"
        let r = NoteSearch.ranges(in: text, query: "WATER")
        XCTAssertEqual(r.map { String(text[$0]) }, ["Water", "water"])
        // Diacritics: "cafe" lights up "Café".
        let t2 = "Café au lait"
        XCTAssertEqual(NoteSearch.ranges(in: t2, query: "cafe").map { String(t2[$0]) }, ["Café"])
        // Overlapping words merge.
        let t3 = "monstera"
        XCTAssertEqual(NoteSearch.ranges(in: t3, query: "mons ster").map { String(t3[$0]) }, ["monster"])
        XCTAssertTrue(NoteSearch.ranges(in: text, query: "").isEmpty)
    }

    func testMatchedTag() {
        let n = note("x", tags: ["Daily"])
        XCTAssertEqual(NoteSearch.matchedTag(of: n, query: "#dai"), "Daily")
        XCTAssertNil(NoteSearch.matchedTag(of: n, query: "work"))
        XCTAssertNil(NoteSearch.matchedTag(of: n, query: ""))
    }

    func testSavedScope() {
        let store = NotesStore(notes: [note("tea", saved: true), note("tea two"), note("coffee", saved: true)])
        XCTAssertEqual(NoteSearch.results(in: SearchScope.saved.notes(in: store), query: "tea").map(\.title), ["tea"])
        XCTAssertEqual(NoteSearch.results(in: SearchScope.all.notes(in: store), query: "tea").count, 2)
    }
}
