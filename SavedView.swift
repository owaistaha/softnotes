import SwiftUI

/// Second tab. The reference only shows the tab switch, so this is a
/// minimal list in the same visual language — ready to be designed further.
struct SavedView: View {
    @Environment(NotesStore.self) private var store
    var onSearch: () -> Void = {}
    var onSelectNote: (Note) -> Void = { _ in }

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
                            NoteRow(note: note) { onSelectNote(note) }
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
        VStack(spacing: 14) {
            StackedIconView(icon: AppTab.saved.icon, size: 56)
            Text("No saved notes")
                .font(.softHeadline)
                .foregroundStyle(Theme.Palette.ink)
            Text("Press and hold a note, then tap Save to keep it here.")
                .font(.softCaption)
                .foregroundStyle(Theme.Palette.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    SavedView()
        .environment(NotesStore())
        .background(Theme.Palette.canvas)
}
