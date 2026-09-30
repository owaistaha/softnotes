import Foundation
import Observation

@Observable
final class NotesStore {
    /// Newest first.
    private(set) var notes: [Note]

    init(notes: [Note] = Note.samples) {
        self.notes = notes.sorted { $0.createdAt > $1.createdAt }
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
    }

    func toggleSaved(_ id: Note.ID) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].isSaved.toggle()
    }

    func delete(_ id: Note.ID) {
        notes.removeAll { $0.id == id }
    }
}
