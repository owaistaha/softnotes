import SwiftUI

struct RecentNotesSection: View {
    let notes: [Note]
    /// False only when the store is completely empty (different copy).
    var hasAnyNotes = true
    var onSeeAll: () -> Void
    var onSelect: (Note, CGRect) -> Void = { _, _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Recent")
                    .font(.softSection)
                    .foregroundStyle(Theme.Palette.ink)
                Spacer()
                Button("See all", action: onSeeAll)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.Palette.inkSecondary)
            }
            // Section label lines up with the header text, not the rows.
            .padding(.horizontal, Theme.Metrics.listTextInset)

            if notes.isEmpty {
                Text(hasAnyNotes
                     ? "Nothing new in the last two days. Tap + to write a note."
                     : "No notes yet. Tap + to write your first one.")
                    .font(.softCaption)
                    .foregroundStyle(Theme.Palette.inkSecondary)
                    .padding(.vertical, 16)
                    .padding(.horizontal, Theme.Metrics.listTextInset)
                    .transition(.blurSlide)
            } else {
                VStack(spacing: Theme.Metrics.rowSpacing) {
                    ForEach(Array(notes.enumerated()), id: \.element.id) { index, note in
                        NoteRow(note: note) { frame in onSelect(note, frame) }
                            // New notes arrive from the top with a soft focus-pull
                            .transition(.blurSlide)
                            .accessibilityIdentifier("recentRow_\(index)")
                    }
                }
            }
        }
    }
}

// MARK: - Row

struct NoteRow: View {
    @Environment(NotesStore.self) private var store
    let note: Note
    /// Called with the row's global frame (the detail overlay grows from it).
    var action: (CGRect) -> Void
    @Environment(\.detailSourceNoteID) private var detailSourceNoteID
    @State private var frame: CGRect = .zero

    private let shape = RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous)

    var body: some View {
        Button { action(frame) } label: {
            HStack(spacing: 14) {
                StackedIconView(icon: note.icon, size: 40, shapeOverride: .squircle)
                    // While this note is open, the overlay's flying icon stands in for it.
                    .opacity(detailSourceNoteID == note.id ? 0 : 1)
                    .transaction { $0.animation = nil }

                VStack(alignment: .leading, spacing: 2) {
                    Text(note.title)
                        .font(.softRowTitle)
                        .foregroundStyle(Theme.Palette.ink)
                        .lineLimit(1)
                    // Re-render once a minute so "Just now" → "1m ago" stays honest.
                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        Text(note.createdAt.softRelative(to: context.date))
                            .font(.softCaption)
                            .foregroundStyle(Theme.Palette.inkSecondary)
                    }
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Palette.inkTertiary)
            }
            .padding(.leading, Theme.Metrics.rowLeading)
            .padding(.trailing, Theme.Metrics.rowTrailing)
            .padding(.vertical, 6)
            .frame(minHeight: Theme.Metrics.rowHeight)
            .background(SoftSurface(shape, elevation: .raised))
            .contentShape(shape)
        }
        .buttonStyle(.pressable(scale: 0.98))
        .onGeometryChange(for: CGRect.self) { proxy in
            let f = proxy.frame(in: .global)
            return CGRect(x: f.minX.rounded(), y: f.minY.rounded(), width: f.width.rounded(), height: f.height.rounded())
        } action: { if $0 != frame { frame = $0 } }
        .contentShape(.contextMenuPreview, shape)
        .contextMenu {
            Button(note.isSaved ? "Remove from Saved" : "Save",
                   systemImage: note.isSaved ? "heart.slash" : "heart") {
                withAnimation(Theme.Motion.snappy) { store.toggleSaved(note.id) }
            }
            Button("Delete", systemImage: "trash", role: .destructive) {
                withAnimation(Theme.Motion.smooth) { store.delete(note.id) }
            }
        }
        // One element: "<title>, <relative time>", a button (no chevron).
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(note.title), \(note.createdAt.softRelative(to: .now))")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens the note")
    }
}
