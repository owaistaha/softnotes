import SwiftUI

/// "See all": every note, newest first, grouped Today / Yesterday / This week /
/// Earlier. An in-place overlay owned by `RootContainerView` (like compose and
/// the note detail — the tab bar only has Home and Saved, and an overlay keeps
/// the measured row frames global, so the detail's icon flight works from here).
///
/// Rows are `NoteRow` (context menu: Save / Delete); tapping one opens the
/// note detail on top of this screen, and closing it returns here.
struct AllNotesView: View {
    @Environment(NotesStore.self) private var store
    var onBack: () -> Void
    var onSearch: () -> Void
    var onSelectNote: (Note, CGRect) -> Void

    var body: some View {
        ZStack {
            Theme.Palette.canvas.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    CircleNavButton(symbol: "chevron.left", label: "Back", id: "allBack", raised: true, action: onBack)
                    Spacer()
                }
                .padding(.horizontal, Theme.Metrics.screenPadding)
                .padding(.top, 8)

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ScreenHeader(title: "All notes", searchID: "allSearchButton", onSearch: onSearch)
                            .padding(.horizontal, Theme.Metrics.listTextInset)
                            .padding(.top, 8)

                        if store.notes.isEmpty {
                            EmptyStateView(icon: NoteIcon(symbol: "tray", tone: .lavender),
                                           title: "No notes yet",
                                           message: "Tap + on Home to write your first note.")
                                .padding(.top, 80)
                        } else {
                            ForEach(NoteGroup.grouped(store.notes), id: \.group) { group, notes in
                                section(group, notes)
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Metrics.listInset)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
            }
        }
    }

    private func section(_ group: NoteGroup, _ notes: [Note]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(group.rawValue)
                .font(.softSection)
                .foregroundStyle(Theme.Palette.inkSecondary)
                .padding(.horizontal, Theme.Metrics.listTextInset)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("allGroup_\(group.rawValue)")
            VStack(spacing: Theme.Metrics.rowSpacing) {
                ForEach(notes) { note in
                    NoteRow(note: note) { frame in onSelectNote(note, frame) }
                        .transition(.blurSlide)
                }
            }
        }
        .padding(.top, 22)
    }
}

#Preview {
    AllNotesView(onBack: {}, onSearch: {}, onSelectNote: { _, _ in })
        .environment(NotesStore())
}
