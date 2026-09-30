import Foundation

enum IconShape: String, Codable, Hashable {
    case circle, squircle
}

struct NoteIcon: Codable, Hashable, Identifiable {
    var symbol: String
    var tone: PastelTone
    var shape: IconShape = .squircle

    var id: String { "\(symbol)-\(tone.rawValue)" }
}

extension NoteIcon {
    /// The 12-icon grid for step 1 of the compose flow ("Pick an icon").
    /// Order mirrors the reference grid, row by row.
    static let library: [NoteIcon] = [
        NoteIcon(symbol: "face.smiling",       tone: .lavender, shape: .circle),
        NoteIcon(symbol: "basket.fill",        tone: .pink,     shape: .circle),
        NoteIcon(symbol: "paperplane.fill",    tone: .indigo,   shape: .circle),
        NoteIcon(symbol: "flame.fill",         tone: .orange,   shape: .squircle),
        NoteIcon(symbol: "sun.max.fill",       tone: .blue,     shape: .squircle),
        NoteIcon(symbol: "cup.and.saucer.fill",tone: .orange,   shape: .circle),
        NoteIcon(symbol: "leaf.fill",          tone: .green,    shape: .squircle),
        NoteIcon(symbol: "heart.fill",         tone: .pink,     shape: .squircle),
        NoteIcon(symbol: "drop.fill",          tone: .blue,     shape: .circle),
        NoteIcon(symbol: "book.closed.fill",   tone: .orange,   shape: .squircle),
        NoteIcon(symbol: "figure.walk",        tone: .green,    shape: .circle),
        NoteIcon(symbol: "star.fill",          tone: .yellow,   shape: .squircle),
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
                 icon: NoteIcon(symbol: "basket.fill", tone: .pink, shape: .circle),
                 tags: ["Errands"], createdAt: .now - 2 * hour),
            Note(title: "Launch day checklist",
                 icon: NoteIcon(symbol: "paperplane.fill", tone: .lavender, shape: .circle),
                 tags: ["Work"], createdAt: .now - 26 * hour, isSaved: true),
            Note(title: "Book club picks",
                 icon: NoteIcon(symbol: "book.closed.fill", tone: .orange),
                 createdAt: .now - 4 * day),
            Note(title: "Water the monstera",
                 icon: NoteIcon(symbol: "leaf.fill", tone: .green),
                 createdAt: .now - 6 * day),
            Note(title: "Gift ideas for Mum",
                 icon: NoteIcon(symbol: "heart.fill", tone: .pink),
                 createdAt: .now - 9 * day, isSaved: true),
            Note(title: "Morning pages",
                 icon: NoteIcon(symbol: "sun.max.fill", tone: .yellow),
                 createdAt: .now - 12 * day),
            Note(title: "Run club route",
                 icon: NoteIcon(symbol: "figure.walk", tone: .green, shape: .circle),
                 createdAt: .now - 15 * day),
            Note(title: "Coffee beans to try",
                 icon: NoteIcon(symbol: "cup.and.saucer.fill", tone: .orange, shape: .circle),
                 createdAt: .now - 21 * day),
        ]
    }()

    /// A stand-in for what the compose flow will produce — used by the
    /// temporary "Save" action so the Home animations can be exercised now.
    static func demo() -> Note {
        Note(
            title: "Have a good day",
            body: "Have a good day",
            icon: NoteIcon(symbol: "sun.max.fill", tone: .blue),
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
