import SwiftUI

/// 01_Home
///
///   Tuesday, 28 September          (🔍)
///   Notes
///
///            [ 3D folder card ]
///
///   Recent                      See all
///   [◉ Have a good day      Just now  >]
///   [◉ Buy fresh cherries   2h ago    >]
///   [◉ Launch day checklist Yesterday >]
struct HomeView: View {
    @Environment(NotesStore.self) private var store
    @Binding var isFolderOpen: Bool
    var onSearch: () -> Void = {}
    var onSeeAll: () -> Void = {}
    var onOpenFolder: () -> Void = {}
    var onSelectNote: (Note) -> Void = { _ in }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenHeader(title: "Notes", onSearch: onSearch)
                    .padding(.top, 8)

                FolderCard(
                    count: store.count,
                    previews: store.folderPreview,
                    isOpen: $isFolderOpen,
                    onTap: onOpenFolder
                )
                // Report the folder's on-screen frame so the compose flow can
                // aim the save → fold → file-away animation at it.
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(key: FolderFrameKey.self, value: proxy.frame(in: .global))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 20)

                RecentNotesSection(
                    notes: store.recent,
                    onSeeAll: onSeeAll,
                    onSelect: onSelectNote
                )
                .padding(.top, 28)
            }
            .padding(.horizontal, Theme.Metrics.screenPadding)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
    }
}

// MARK: - Header (shared by Home & Saved)

struct ScreenHeader: View {
    let title: String
    var showsDate: Bool = true
    var onSearch: () -> Void

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEEEdMMMM")   // "Tuesday, 28 September"
        return formatter
    }()

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                if showsDate {
                    Text(Self.dateFormatter.string(from: .now))
                        .font(.softCaption)
                        .foregroundStyle(Theme.Palette.inkSecondary)
                }
                Text(title)
                    .font(.softLargeTitle)
                    .tracking(-0.6)
                    .foregroundStyle(Theme.Palette.ink)
                    .contentTransition(.interpolate)
            }
            Spacer()
            Button(action: onSearch) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.Palette.ink)
                    .frame(width: 40, height: 40)
                    .background(SoftSurface(Circle(), elevation: .raised))
            }
            .buttonStyle(.pressable(scale: 0.9))
            .accessibilityLabel("Search notes")
            .padding(.bottom, 4)
        }
    }
}

// MARK: - Folder frame preference

struct FolderFrameKey: PreferenceKey {
    static let defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}

#Preview {
    @Previewable @State var open = false
    HomeView(isFolderOpen: $open)
        .environment(NotesStore())
        .background(Theme.Palette.canvas)
}
