import Foundation
import Observation
import os

/// The notes, newest first, kept on disk between launches.
///
/// Persistence rules (Step 7):
/// • Loaded once, synchronously, in `init` (a small file).
/// • First launch only — no file AND `hasSeeded` unset — seeds `Note.samples`.
///   After that an empty list stays empty.
/// • Every mutation marks the store dirty and (re)arms a ≈300 ms debounce; the
///   write itself (encode + atomic file write) runs on a background serial
///   queue. A mutation does nothing else — in particular no I/O — so it is
///   safe to call inside the save timeline's animation closures.
/// • `flush()` writes immediately and waits; the app calls it when the scene
///   leaves `.active`.
/// • A file that can't be read is moved aside by the persistence layer and
///   the store starts empty; if even that failed, writes are disabled so the
///   original is never overwritten.
@Observable
final class NotesStore {
    /// Newest first.
    private(set) var notes: [Note]

    @ObservationIgnored private let persistence: NotePersisting
    @ObservationIgnored private let debounce: Duration
    @ObservationIgnored private let writeQueue = DispatchQueue(label: "softnotes.store.write", qos: .utility)
    @ObservationIgnored private var debounceTask: Task<Void, Never>?
    @ObservationIgnored private var isDirty = false
    @ObservationIgnored private var writesEnabled = true
    @ObservationIgnored private let log = Logger(subsystem: "com.owaistaha.softnotes", category: "persistence")

    init(persistence: NotePersisting, debounce: Duration = .milliseconds(300)) {
        self.persistence = persistence
        self.debounce = debounce
        switch persistence.load() {
        case .notes(let loaded, _):
            notes = Self.newestFirst(loaded)
            if !persistence.hasSeeded { persistence.hasSeeded = true }
        case .missing:
            if persistence.hasSeeded {
                notes = []                                  // emptied by the user — stays empty
            } else {
                notes = Self.newestFirst(Note.samples)
                do {
                    try persistence.save(notes)
                    persistence.hasSeeded = true
                } catch {
                    note("seeding failed: \(error)")        // tries again next launch
                }
            }
        case .corrupt(let movedTo):
            notes = []
            persistence.hasSeeded = true                    // never re-seed over a damaged file
            if movedTo == nil { writesEnabled = false }     // can't move it → don't touch it
        }
    }

    /// Previews and tests that don't care about disk: sample data, no writes.
    convenience init(notes: [Note] = Note.samples) {
        self.init(persistence: InMemoryNotePersistence(notes: notes, hasSeeded: true))
    }

    var count: Int { notes.count }

    /// Home "Recent" list — notes from the last 48h, max three.
    var recent: [Note] {
        let cutoff = Date.now.addingTimeInterval(-48 * 3600)
        return Array(notes.filter { $0.createdAt > cutoff }.prefix(3))
    }

    /// The three icons peeking out of the folder.
    var folderPreview: [Note] { Array(notes.prefix(3)) }

    var saved: [Note] { notes.filter(\.isSaved) }

    func add(_ note: Note) {
        notes.insert(note, at: 0)
        scheduleSave()
    }

    func toggleSaved(_ id: Note.ID) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].isSaved.toggle()
        scheduleSave()
    }

    /// Edits one note in place (detail screen). Persisted like every other
    /// mutation (debounced). A change that leaves the note equal writes nothing.
    func update(_ id: Note.ID, _ change: (inout Note) -> Void) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        var edited = notes[index]
        change(&edited)
        guard edited != notes[index] else { return }
        notes[index] = edited
        scheduleSave()
    }

    func note(withID id: Note.ID) -> Note? { notes.first { $0.id == id } }

    func delete(_ id: Note.ID) {
        let before = notes.count
        notes.removeAll { $0.id == id }
        if notes.count != before { scheduleSave() }
    }

    // MARK: - Writing

    /// Marks the store dirty and re-arms the debounce. Cheap: no encoding, no
    /// I/O — only a timer — so animation closures can call the mutators.
    private func scheduleSave() {
        guard writesEnabled else { return }
        isDirty = true
        debounceTask?.cancel()
        let delay = debounce
        debounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.writeNow()
        }
    }

    /// Hands a snapshot to the background queue (copy-on-write: no copying here).
    private func writeNow() {
        guard isDirty, writesEnabled else { return }
        isDirty = false
        let snapshot = notes
        let persistence = persistence
        writeQueue.async { [weak self] in
            do {
                try persistence.save(snapshot)
            } catch {
                self?.note("write failed: \(error)")
                DispatchQueue.main.async { self?.isDirty = true }   // next mutation / flush retries
            }
        }
    }

    /// Writes any pending change now and waits until it is on disk. Called
    /// when the scene goes inactive / to the background.
    func flush() {
        debounceTask?.cancel()
        debounceTask = nil
        writeNow()
        writeQueue.sync {}
    }

    private static func newestFirst(_ notes: [Note]) -> [Note] {
        // Stable for equal dates (the file order is already newest first).
        notes.enumerated()
            .sorted { $0.element.createdAt != $1.element.createdAt
                ? $0.element.createdAt > $1.element.createdAt : $0.offset < $1.offset }
            .map(\.element)
    }

    private func note(_ message: String) {
        #if DEBUG
        print("PERSISTENCE: \(message)")
        log.error("\(message)")
        #endif
    }
}

// MARK: - Launch configuration

extension NotesStore {
    /// The store the app runs with: the real file in Application Support.
    ///
    /// DEBUG launch arguments (tests): `-resetStore` deletes the file and the
    /// seeded flag first; `-inMemoryStore` uses no disk; `-emptyStore` marks
    /// the store as already seeded (use with `-resetStore`: starts with zero
    /// notes). The demo flows (`-demoSave`, `-demoFold`, `-keyboardCycles`)
    /// never touch the real file unless `-persistDemo` is also passed.
    static func makeForLaunch(arguments: [String] = ProcessInfo.processInfo.arguments) -> NotesStore {
        #if DEBUG
        let demo = ["-demoSave", "-demoFold", "-keyboardCycles"].contains { arguments.contains($0) }
        let inMemory = arguments.contains("-inMemoryStore") || (demo && !arguments.contains("-persistDemo"))
        let persistence: NotePersisting = inMemory ? InMemoryNotePersistence() : FileNotePersistence.standard
        if arguments.contains("-resetStore") { persistence.reset() }
        if arguments.contains("-emptyStore") { persistence.hasSeeded = true }
        return NotesStore(persistence: persistence)
        #else
        return NotesStore(persistence: FileNotePersistence.standard)
        #endif
    }
}
