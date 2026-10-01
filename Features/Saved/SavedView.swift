import SwiftUI

/// Second tab. The reference only shows the tab switch, so this is a
/// minimal list in the same visual language — ready to be designed further.
struct SavedView: View {
    @Environment(NotesStore.self) private var store
    var onSearch: () -> Void = {}
    var onSelectNote: (Note, CGRect) -> Void = { _, _ in }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenHeader(title: "Saved", onSearch: onSearch)
                    .padding(.horizontal, Theme.Metrics.listTextInset)
                    .padding(.top, 8)

                if store.saved.isEmpty {
                    emptyState
                        .padding(.top, 80)
                        .transition(.blurSlide)
                } else {
                    VStack(spacing: Theme.Metrics.rowSpacing) {
                        ForEach(store.saved) { note in
                            NoteRow(note: note) { frame in onSelectNote(note, frame) }
                                .transition(.blurSlide)
                        }
                    }
                    .padding(.top, 24)
                }
            }
            .padding(.horizontal, Theme.Metrics.listInset)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
    }

    private var emptyState: some View {
        EmptyStateView(icon: AppTab.saved.icon, title: "No saved notes",
                       message: "Press and hold a note, then tap Save to keep it here.")
    }
}

#Preview {
    SavedView()
        .environment(NotesStore())
        .background(Theme.Palette.canvas)
}
