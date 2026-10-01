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
    /// Header + Recent. Hidden while the save flight has Home zoomed on the
    /// folder; they blur back in with the zoom-out.
    var showsChrome: Bool = true
    /// A just-filed note whose row is held back from Recent (it enters later).
    var heldNoteID: Note.ID? = nil
    /// The note whose chip the save flight hands over (appears in place).
    var landingNoteID: Note.ID? = nil
    /// The save flight is about to land: the centre chip slot is emptied.
    var vacatesCentreChip: Bool = false
    /// Shown on the count bubble ahead of the store: the count rolls just
    /// before the flying icon settles (reference), the note is added after.
    var countLead: Int = 0
    var onSearch: () -> Void = {}
    /// Content vs viewport height — Home scrolls only on short screens.
    @State private var contentHeight: CGFloat = 0
    @State private var viewportHeight: CGFloat = 0
    private var homeScrolls: Bool { contentHeight > viewportHeight + 1 }
    var onSeeAll: () -> Void = {}
    var onOpenFolder: () -> Void = {}
    var onSelectNote: (Note) -> Void = { _ in }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenHeader(title: "Notes", onSearch: onSearch)
                    .padding(.horizontal, Theme.Metrics.listTextInset)
                    .padding(.top, 8)
                    .modifier(ChromeVisibility(isVisible: showsChrome))

                FolderCard(
                    count: store.count + countLead,
                    previews: store.folderPreview,
                    isOpen: $isFolderOpen,
                    landingNoteID: landingNoteID,
                    vacatesCentre: vacatesCentreChip,
                    receivedCount: store.count,
                    sharesDragsWithScroll: homeScrolls,
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
                .padding(.top, 14)

                RecentNotesSection(
                    notes: store.recent.filter { $0.id != heldNoteID },
                    hasAnyNotes: store.count > 0 || heldNoteID != nil,
                    onSeeAll: onSeeAll,
                    onSelect: onSelectNote
                )
                .padding(.top, 28)
                .modifier(ChromeVisibility(isVisible: showsChrome))
            }
            // Rows run wider than the header text (per reference).
            .padding(.horizontal, Theme.Metrics.listInset)
            .padding(.bottom, 32)
            .onGeometryChange(for: CGFloat.self) { $0.size.height.rounded() } action: { height in
                if height != contentHeight { contentHeight = height }
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height.rounded() } action: { height in
            if height != viewportHeight { viewportHeight = height }
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
    }
}

/// Header / Recent fading and focusing back in after the save's zoom-out.
private struct ChromeVisibility: ViewModifier {
    var isVisible: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .blur(radius: isVisible ? 0 : 8)
            .animation(Theme.Motion.chromeIn, value: isVisible)
    }
}

// MARK: - Header (shared by Home & Saved)

struct ScreenHeader: View {
    let title: String
    var showsDate: Bool = true
    var onSearch: () -> Void

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        // Fixed English format to match the reference ("Tuesday, 28 September"),
        // independent of the device's region settings.
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter
    }()

    var body: some View {
        HStack(alignment: .center) {
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
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.Palette.ink)
                    .frame(width: Theme.Metrics.searchButton, height: Theme.Metrics.searchButton)
                    .background(SoftSurface(Circle(), elevation: .raised))
            }
            .buttonStyle(.pressable(scale: 0.9))
            .accessibilityLabel("Search notes")
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
