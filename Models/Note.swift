import Foundation
import UIKit

enum IconShape: String, Codable, Hashable {
    case circle, squircle
}

struct NoteIcon: Codable, Hashable, Identifiable {
    var symbol: String
    var tone: PastelTone
    var shape: IconShape = .squircle

    var id: String { "\(symbol)-\(tone.rawValue)" }

    // MARK: Tolerant coding (stored files outlive SF Symbol / tone renames)

    /// Shown when a stored symbol isn't a symbol on this OS (renamed or
    /// removed while the app was in development).
    static let fallbackSymbol = "doc.text"
    static let fallbackTone: PastelTone = .lavender

    private enum CodingKeys: String, CodingKey { case symbol, tone, shape }

    init(symbol: String, tone: PastelTone, shape: IconShape = .squircle) {
        self.symbol = symbol
        self.tone = tone
        self.shape = shape
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let stored = (try? c.decodeIfPresent(String.self, forKey: .symbol)) ?? nil
        symbol = stored.flatMap { Self.isValidSymbol($0) ? $0 : nil } ?? Self.fallbackSymbol
        let tone = (try? c.decodeIfPresent(String.self, forKey: .tone)) ?? nil
        self.tone = tone.flatMap(PastelTone.init(rawValue:)) ?? Self.fallbackTone
        let shape = (try? c.decodeIfPresent(String.self, forKey: .shape)) ?? nil
        self.shape = shape.flatMap(IconShape.init(rawValue:)) ?? .squircle
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(symbol, forKey: .symbol)
        try c.encode(tone.rawValue, forKey: .tone)
        try c.encode(shape.rawValue, forKey: .shape)
    }

    /// Is `name` a real SF Symbol on this OS? (A missing one renders blank.)
    static func isValidSymbol(_ name: String) -> Bool {
        UIImage(systemName: name) != nil
    }

    /// VoiceOver name. Spoken names for the library's symbols (the raw
    /// symbol name reads as "Sun max", "Figure walk"); anything else falls
    /// back to the symbol ("cup.and.saucer" → "Cup and saucer").
    var accessibilityName: String {
        if let name = Self.spokenNames[symbol] { return name }
        let words = symbol.split(separator: ".").joined(separator: " ")
        return words.prefix(1).uppercased() + words.dropFirst()
    }

    private static let spokenNames: [String: String] = [
        "face.smiling": "Smiling face", "sun.max": "Sun", "paperplane": "Paper plane",
        "book.closed": "Book", "figure.walk": "Walking person", "drop": "Water drop",
        "house": "Home", "heart": "Heart",
    ]
}

extension NoteIcon {
    /// The 12-icon grid for step 1 of the compose flow ("Pick an icon").
    /// Order mirrors the reference grid, row by row.
    /// Outline (non-.fill) symbols to match the reference's thin line glyphs.
    /// All verified present in SF Symbols 5 (iOS 17).
    /// The picker opens with this one selected (reference: row 2, column 1).
    static let defaultIcon: NoteIcon = library[4]

    static let library: [NoteIcon] = [
        NoteIcon(symbol: "face.smiling",    tone: .lavender, shape: .circle),
        NoteIcon(symbol: "basket",          tone: .pink,     shape: .circle),
        NoteIcon(symbol: "paperplane",      tone: .indigo,   shape: .circle),
        NoteIcon(symbol: "flame",           tone: .orange,   shape: .squircle),
        NoteIcon(symbol: "sun.max",         tone: .blue,     shape: .squircle),
        NoteIcon(symbol: "cup.and.saucer",  tone: .orange,   shape: .circle),
        NoteIcon(symbol: "leaf",            tone: .green,    shape: .squircle),
        NoteIcon(symbol: "heart",           tone: .pink,     shape: .squircle),
        NoteIcon(symbol: "drop",            tone: .blue,     shape: .circle),
        NoteIcon(symbol: "book.closed",     tone: .orange,   shape: .squircle),
        NoteIcon(symbol: "figure.walk",     tone: .green,    shape: .circle),
        NoteIcon(symbol: "star",            tone: .yellow,   shape: .squircle),
    ]
}

struct Note: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var body: String
    var icon: NoteIcon
    var tags: [String]
    var createdAt: Date
    var isSaved: Bool

    // MARK: Tolerant coding — only a title and a date are required; one bad
    // note is skipped by the loader, never the whole file.

    private enum CodingKeys: String, CodingKey { case id, title, body, icon, tags, createdAt, isSaved }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let rawID = (try? c.decodeIfPresent(String.self, forKey: .id)) ?? nil
        id = rawID.flatMap(UUID.init(uuidString:)) ?? UUID()
        title = try c.decode(String.self, forKey: .title)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        body = (try? c.decodeIfPresent(String.self, forKey: .body)) ?? ""
        icon = (try? c.decodeIfPresent(NoteIcon.self, forKey: .icon)) ?? NoteIcon.defaultIcon
        tags = (try? c.decodeIfPresent([String].self, forKey: .tags)) ?? []
        isSaved = (try? c.decodeIfPresent(Bool.self, forKey: .isSaved)) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id.uuidString, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(body, forKey: .body)
        try c.encode(icon, forKey: .icon)
        try c.encode(tags, forKey: .tags)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(isSaved, forKey: .isSaved)
    }

    init(
        id: UUID = UUID(),
        title: String,
        body: String = "",
        icon: NoteIcon,
        tags: [String] = [],
        createdAt: Date = .now,
        isSaved: Bool = false
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.icon = icon
        self.tags = tags
        self.createdAt = createdAt
        self.isSaved = isSaved
    }
}

// MARK: - Sample data (matches the reference's starting state: 8 notes, 2 recent)

extension Note {
    static let samples: [Note] = {
        let hour: TimeInterval = 3600
        let day: TimeInterval = 86_400
        return [
            Note(title: "Buy fresh cherries",
                 icon: NoteIcon(symbol: "basket", tone: .pink, shape: .circle),
                 tags: ["Errands"], createdAt: .now - 2 * hour),
            Note(title: "Launch day checklist",
                 icon: NoteIcon(symbol: "paperplane", tone: .lavender, shape: .circle),
                 tags: ["Work"], createdAt: .now - 26 * hour, isSaved: true),
            Note(title: "Book club picks",
                 icon: NoteIcon(symbol: "book.closed", tone: .orange),
                 createdAt: .now - 4 * day),
            Note(title: "Water the monstera",
                 icon: NoteIcon(symbol: "leaf", tone: .green),
                 createdAt: .now - 6 * day),
            Note(title: "Gift ideas for Mum",
                 icon: NoteIcon(symbol: "heart", tone: .pink),
                 createdAt: .now - 9 * day, isSaved: true),
            Note(title: "Morning pages",
                 icon: NoteIcon(symbol: "sun.max", tone: .yellow),
                 createdAt: .now - 12 * day),
            Note(title: "Run club route",
                 icon: NoteIcon(symbol: "figure.walk", tone: .green, shape: .circle),
                 createdAt: .now - 15 * day),
            Note(title: "Coffee beans to try",
                 icon: NoteIcon(symbol: "cup.and.saucer", tone: .orange, shape: .circle),
                 createdAt: .now - 21 * day),
        ]
    }()

    /// A stand-in for what the compose flow will produce — used by the
    /// temporary "Save" action so the Home animations can be exercised now.
    static func demo() -> Note {
        Note(
            title: "Have a good day",
            body: "Have a good day",
            icon: NoteIcon(symbol: "sun.max", tone: .blue),
            tags: ["Daily"]
        )
    }
}

// MARK: - Relative time ("Just now", "2h ago", "Yesterday")

extension Date {
    func softRelative(to now: Date = .now) -> String {
        let seconds = now.timeIntervalSince(self)
        let calendar = Calendar.current

        if seconds < 60 { return "Just now" }
        if seconds < 3600 { return "\(Int(seconds / 60))m ago" }
        if calendar.isDate(self, inSameDayAs: now) { return "\(Int(seconds / 3600))h ago" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(self, inSameDayAs: yesterday) { return "Yesterday" }
        return formatted(.dateTime.day().month(.abbreviated))
    }
}
