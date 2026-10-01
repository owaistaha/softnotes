import SwiftUI

/// What the search overlay is searching and for what. Owned by the container
/// (it needs the query to decide whether a result is still listed when the
/// note detail closes).
@Observable
final class SearchModel {
    var query = ""
    let scope: SearchScope
    init(scope: SearchScope) { self.scope = scope }
}

/// Search: an in-place overlay (like All Notes and the note detail), opened by
/// the search button on Home, Saved and All Notes. Closing returns to where the
/// user was.
///
///   [🔍 Search notes          ✕ ]  (×)       ← soft-UI field (SoftSurface), keyboard up on open
///   Recent / 3 results                         ← empty query: the last few notes
///   [◉ Buy fresh **cherries**  2h ago >]       ← NoteRow, matches emphasised
///
/// Matching is case- and diacritic-insensitive on text and tag (`NoteSearch`);
/// the Saved screen searches only saved notes (`SearchScope.saved`). No state
/// is written during layout: results are computed in `body` from the query,
/// the keyboard is handled by `keyboardOverlapPadding()`.
struct SearchView: View {
    @Environment(NotesStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var model: SearchModel
    var onClose: () -> Void
    var onSelectNote: (Note, CGRect) -> Void
    @FocusState private var isFocused: Bool

    private var scopeNotes: [Note] { model.scope.notes(in: store) }
    private var results: [Note] { NoteSearch.results(in: scopeNotes, query: model.query) }
    private var isQueryEmpty: Bool { NoteSearch.isEmpty(model.query) }
    private var shownQuery: String { model.query.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        let results = results
        ZStack {
            Theme.Palette.canvas.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    field
                    CircleNavButton(symbol: "xmark", label: "Close search", id: "searchClose", raised: false) {
                        isFocused = false
                        onClose()
                    }
                }
                .padding(.horizontal, Theme.Metrics.screenPadding)
                .padding(.top, 8)

                ScrollView {
                    content(results)
                        .padding(.horizontal, Theme.Metrics.listInset)
                        .padding(.top, 22)
                        .padding(.bottom, 32)
                        .animation(reduceMotion ? Theme.Motion.crossFade : Theme.Motion.snappy,
                                   value: results.map(\.id))
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
            .keyboardOverlapPadding()
        }
        .task { isFocused = true }                         // keyboard up on open
        // VoiceOver: say how many notes match (only when that changes).
        .onChange(of: announcement(for: results)) { _, text in
            guard let text else { return }
            AccessibilityNotification.Announcement(text).post()
        }
    }

    // MARK: Field

    private var field: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.Palette.inkSecondary)
                .accessibilityHidden(true)

            TextField("", text: $model.query,
                      prompt: Text(model.scope.placeholder).foregroundStyle(Theme.Palette.inkTertiary))
                .font(.softBody)
                .foregroundStyle(Theme.Palette.ink)
                .tint(Theme.Palette.amber)
                .focused($isFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onSubmit { isFocused = false }
                .accessibilityLabel(model.scope == .saved ? "Search saved notes" : "Search notes")
                .accessibilityHint("Type a word or a tag. Results update as you type.")
                .accessibilityIdentifier("searchField")

            if !model.query.isEmpty {
                Button {
                    model.query = ""
                    isFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(Theme.Palette.inkTertiary)
                }
                .buttonStyle(.pressable(scale: 0.88))
                .accessibilityLabel("Clear search")
                .accessibilityIdentifier("searchClear")
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: Theme.Metrics.searchButton)
        .background(SoftSurface(Capsule(), elevation: .raised))
        .animation(Theme.Motion.snappy, value: model.query.isEmpty)
    }

    // MARK: Results

    @ViewBuilder
    private func content(_ results: [Note]) -> some View {
        if isQueryEmpty && scopeNotes.isEmpty {
            EmptyStateView(
                icon: model.scope == .saved ? AppTab.saved.icon : NoteIcon(symbol: "tray", tone: .lavender),
                title: model.scope == .saved ? "No saved notes" : "No notes yet",
                message: model.scope == .saved
                    ? "Press and hold a note, then tap Save to keep it here."
                    : "Tap + on Home to write your first note."
            )
            .padding(.top, 60)
        } else if results.isEmpty {
            EmptyStateView(
                icon: NoteIcon(symbol: "magnifyingglass", tone: .lavender),
                title: "No notes match “\(shownQuery)”",
                message: "Try another word, or a tag like #daily."
            )
            .padding(.top, 60)
            .accessibilityIdentifier("searchEmpty")
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text(isQueryEmpty ? "Recent" : "\(results.count) \(results.count == 1 ? "result" : "results")")
                    .font(.softSection)
                    .foregroundStyle(Theme.Palette.inkSecondary)
                    .padding(.horizontal, Theme.Metrics.listTextInset)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("searchHeading")
                VStack(spacing: Theme.Metrics.rowSpacing) {
                    ForEach(results) { note in
                        NoteRow(note: note, query: model.query) { frame in
                            isFocused = false
                            onSelectNote(note, frame)
                        }
                        .transition(.opacity)
                    }
                }
            }
        }
    }

    /// "3 notes found" / "No notes match" — nil while the query is empty.
    private func announcement(for results: [Note]) -> String? {
        guard !isQueryEmpty else { return nil }
        return results.isEmpty ? "No notes match" : "\(results.count) \(results.count == 1 ? "note" : "notes") found"
    }
}

#Preview {
    SearchView(model: SearchModel(scope: .all), onClose: {}, onSelectNote: { _, _ in })
        .environment(NotesStore())
}
