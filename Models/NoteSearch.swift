import Foundation

// MARK: - Grouping for the All Notes screen

/// Today / Yesterday / This week / Earlier.
enum NoteGroup: String, CaseIterable, Identifiable {
    case today = "Today"
    case yesterday = "Yesterday"
    case thisWeek = "This week"
    case earlier = "Earlier"

    var id: String { rawValue }

    /// "This week" is the calendar week of `now`, minus today and yesterday
    /// (which have their own groups).
    static func of(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> NoteGroup {
        if date > now || calendar.isDate(date, inSameDayAs: now) { return .today }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) { return .yesterday }
        if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) { return .thisWeek }
        return .earlier
    }

    /// Newest first inside each group; empty groups are left out.
    static func grouped(_ notes: [Note], now: Date = .now, calendar: Calendar = .current)
        -> [(group: NoteGroup, notes: [Note])]
    {
        let sorted = notes.enumerated()
            .sorted { $0.element.createdAt != $1.element.createdAt
                ? $0.element.createdAt > $1.element.createdAt : $0.offset < $1.offset }
            .map(\.element)
        var buckets: [NoteGroup: [Note]] = [:]
        for note in sorted {
            buckets[Self.of(note.createdAt, now: now, calendar: calendar), default: []].append(note)
        }
        return allCases.compactMap { group in buckets[group].map { (group, $0) } }
    }
}

// MARK: - Search

/// What a search covers: everything, or only saved notes (the Saved screen).
enum SearchScope: Equatable {
    case all, saved

    var placeholder: String { self == .saved ? "Search saved notes" : "Search notes" }

    func notes(in store: NotesStore) -> [Note] { self == .saved ? store.saved : store.notes }
}

/// Case- and diacritic-insensitive matching on a note's text and tags.
///
/// The query is split into words; a note matches when EVERY word is found in
/// its text (title + body) or in one of its tags. A leading "#" is ignored
/// ("#daily" finds the Daily tag).
enum NoteSearch {
    /// How many notes an empty query shows.
    static let recentLimit = 5

    static func words(_ query: String) -> [String] {
        query.split(whereSeparator: \.isWhitespace)
            .map { String($0).drop(while: { $0 == "#" }) }
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    static func isEmpty(_ query: String) -> Bool { words(query).isEmpty }

    private static let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]

    private static func contains(_ haystack: String, _ word: String) -> Bool {
        haystack.range(of: word, options: options) != nil
    }

    static func matches(_ note: Note, query: String) -> Bool {
        let words = words(query)
        guard !words.isEmpty else { return true }
        let text = note.title + " " + note.body
        return words.allSatisfy { word in
            contains(text, word) || note.tags.contains { contains($0, word) }
        }
    }

    /// Matches newest first; an empty query gives the latest `recentLimit` notes.
    static func results(in notes: [Note], query: String) -> [Note] {
        let newestFirst = notes.enumerated()
            .sorted { $0.element.createdAt != $1.element.createdAt
                ? $0.element.createdAt > $1.element.createdAt : $0.offset < $1.offset }
            .map(\.element)
        if isEmpty(query) { return Array(newestFirst.prefix(recentLimit)) }
        return newestFirst.filter { matches($0, query: query) }
    }

    /// Where the query words sit in `text` (merged, in order) — for emphasis.
    static func ranges(in text: String, query: String) -> [Range<String.Index>] {
        var found: [Range<String.Index>] = []
        for word in words(query) {
            var start = text.startIndex
            while start < text.endIndex,
                  let r = text.range(of: word, options: options, range: start..<text.endIndex) {
                found.append(r)
                start = r.upperBound
            }
        }
        found.sort { $0.lowerBound < $1.lowerBound }
        var merged: [Range<String.Index>] = []
        for r in found {
            if let last = merged.last, r.lowerBound <= last.upperBound {
                merged[merged.count - 1] = last.lowerBound..<max(last.upperBound, r.upperBound)
            } else {
                merged.append(r)
            }
        }
        return merged
    }

    /// The tag a query word matched (for showing "#daily" emphasised), if any.
    static func matchedTag(of note: Note, query: String) -> String? {
        let words = words(query)
        guard !words.isEmpty else { return nil }
        return note.tags.first { tag in words.contains { contains(tag, $0) } }
    }
}
