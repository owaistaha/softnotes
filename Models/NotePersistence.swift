import Foundation
import os

// MARK: - Contract

/// What loading found on disk.
enum NoteLoadResult: Equatable {
    /// A readable file. `skipped` notes inside it could not be decoded (the
    /// original was copied aside before anything can overwrite it).
    case notes([Note], skipped: Int)
    /// No file at all.
    case missing
    /// The file is not a readable envelope. It was moved aside (`movedTo`);
    /// `nil` means even that failed, and nothing may be written over it.
    case corrupt(movedTo: URL?)
}

/// Where notes live between launches. The store only talks to this protocol,
/// so tests inject an in-memory or temp-directory implementation.
protocol NotePersisting: AnyObject, Sendable {
    func load() -> NoteLoadResult
    /// Whole-array write (called off the main thread).
    func save(_ notes: [Note]) throws
    /// Set once the sample notes were seeded (or a file was ever read):
    /// an empty list must stay empty and never be re-seeded.
    var hasSeeded: Bool { get set }
    /// DEBUG `-resetStore`: delete the file and the seeded flag.
    func reset()
}

// MARK: - Format: {"version": 1, "notes": [...]}, ISO 8601 dates

enum NoteCodec {
    static let currentVersion = 1

    enum DecodeError: Error, Equatable {
        case notAnEnvelope
        case unsupportedVersion(Int)
    }

    struct Decoded {
        var notes: [Note]
        var skipped: Int
    }

    private struct Envelope: Encodable {
        var version: Int
        var notes: [Note]
    }

    /// One bad note must not drop the others: failures decode to nil.
    private struct Lossy: Decodable {
        var note: Note?
        init(from decoder: Decoder) throws { note = try? Note(from: decoder) }
    }

    private struct LossyEnvelope: Decodable {
        var version: Int
        var notes: [Lossy]
    }

    static func encode(_ notes: [Note]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, enc in
            var c = enc.singleValueContainer()
            try c.encode(NoteDates.string(from: date))
        }
        return try encoder.encode(Envelope(version: currentVersion, notes: notes))
    }

    static func decode(_ data: Data) throws -> Decoded {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { dec in
            let raw = try dec.singleValueContainer().decode(String.self)
            guard let date = NoteDates.date(from: raw) else {
                throw DecodingError.dataCorrupted(.init(codingPath: dec.codingPath, debugDescription: "bad date \(raw)"))
            }
            return date
        }
        let envelope: LossyEnvelope
        do { envelope = try decoder.decode(LossyEnvelope.self, from: data) } catch { throw DecodeError.notAnEnvelope }
        guard envelope.version == currentVersion else { throw DecodeError.unsupportedVersion(envelope.version) }
        let good = envelope.notes.compactMap(\.note)
        return Decoded(notes: good, skipped: envelope.notes.count - good.count)
    }
}

enum NoteDates {
    private static let style = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    private static let plain = Date.ISO8601FormatStyle()

    static func string(from date: Date) -> String { date.formatted(style) }

    /// Accepts both "…:30.123Z" and "…:30Z".
    static func date(from string: String) -> Date? {
        (try? style.parse(string)) ?? (try? plain.parse(string))
    }
}

// MARK: - The real file

/// `Application Support/SoftNotes/notes.json`, written atomically.
final class FileNotePersistence: NotePersisting, @unchecked Sendable {
    let directory: URL
    private let defaults: UserDefaults
    private static let seededKey = "softnotes.hasSeededNotes"
    private let log = Logger(subsystem: "com.owaistaha.softnotes", category: "persistence")

    init(directory: URL, defaults: UserDefaults = .standard) {
        self.directory = directory
        self.defaults = defaults
    }

    static var standard: FileNotePersistence {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )) ?? FileManager.default.temporaryDirectory
        return FileNotePersistence(directory: base.appendingPathComponent("SoftNotes", isDirectory: true))
    }

    var fileURL: URL { directory.appendingPathComponent("notes.json") }

    var hasSeeded: Bool {
        get { defaults.bool(forKey: Self.seededKey) }
        set { defaults.set(newValue, forKey: Self.seededKey) }
    }

    func load() -> NoteLoadResult {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return .missing }
        do {
            let decoded = try NoteCodec.decode(try Data(contentsOf: fileURL))
            if decoded.skipped > 0 {
                // Notes are about to be dropped from memory; keep the original.
                let copy = backupURL(kind: "partial")
                try? FileManager.default.copyItem(at: fileURL, to: copy)
                note("\(decoded.skipped) undecodable note(s) skipped; original kept as \(copy.lastPathComponent)")
            }
            return .notes(decoded.notes, skipped: decoded.skipped)
        } catch {
            let target = backupURL(kind: "corrupt")
            do {
                try FileManager.default.moveItem(at: fileURL, to: target)
                note("unreadable notes file (\(error)); moved to \(target.lastPathComponent)")
                return .corrupt(movedTo: target)
            } catch {
                note("unreadable notes file and it could not be moved aside: \(error)")
                return .corrupt(movedTo: nil)
            }
        }
    }

    func save(_ notes: [Note]) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try NoteCodec.encode(notes).write(to: fileURL, options: .atomic)
    }

    func reset() {
        try? FileManager.default.removeItem(at: fileURL)
        defaults.removeObject(forKey: Self.seededKey)
    }

    /// `notes.corrupt-20261001T101500Z.json` (numbered if that exists).
    private func backupURL(kind: String) -> URL {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        let stamp = f.string(from: .now)
        var url = directory.appendingPathComponent("notes.\(kind)-\(stamp).json")
        var n = 1
        while FileManager.default.fileExists(atPath: url.path) {
            n += 1
            url = directory.appendingPathComponent("notes.\(kind)-\(stamp)-\(n).json")
        }
        return url
    }

    private func note(_ message: String) {
        #if DEBUG
        print("PERSISTENCE: \(message)")
        log.error("\(message)")
        #endif
    }
}

// MARK: - No disk

/// Previews, `-inMemoryStore` and the demo flows: same seeding rules, nothing
/// is written anywhere. `saveCount` lets tests count writes.
final class InMemoryNotePersistence: NotePersisting, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [Note]?
    private var seeded: Bool
    private var saves = 0
    private var failing = false

    init(notes: [Note]? = nil, hasSeeded: Bool = false) {
        stored = notes
        seeded = hasSeeded
    }

    var hasSeeded: Bool {
        get { lock.withLock { seeded } }
        set { lock.withLock { seeded = newValue } }
    }
    var saveCount: Int { lock.withLock { saves } }
    var lastSaved: [Note]? { lock.withLock { stored } }
    /// Tests: make the next saves throw.
    var failsToSave: Bool {
        get { lock.withLock { failing } }
        set { lock.withLock { failing = newValue } }
    }

    func load() -> NoteLoadResult {
        lock.withLock { stored.map { .notes($0, skipped: 0) } ?? .missing }
    }

    func save(_ notes: [Note]) throws {
        try lock.withLock {
            if failing { throw CocoaError(.fileWriteUnknown) }
            stored = notes
            saves += 1
        }
    }

    func reset() { lock.withLock { stored = nil; seeded = false } }
}
