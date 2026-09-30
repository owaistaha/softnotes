import SwiftUI

/// The app shell. Owns everything that has to be coordinated *across* screens:
///
/// • the store and the selected tab
/// • the compose flow, presented as an in-place overlay (not a sheet) so the
///   FAB can morph into its Next button and the saved note can fly back
///   into the Home folder
/// • the folder's on-screen frame (via `FolderFrameKey`) and its open state
///
///   ZStack
///   ├─ canvas
///   ├─ tab content (Home | Saved) ── recedes + blurs while composing
///   │    └─ safeAreaInset(bottom): FloatingTabBar (+ FAB)
///   └─ ComposeFlowView (when composing)
struct RootContainerView: View {
    @State private var store = NotesStore()
    @State private var selectedTab: AppTab = .home
    @State private var isComposing = false
    @State private var isFolderOpen = false
    @State private var folderFrame: CGRect = .zero
    /// Fresh for every compose session (see `startComposing`).
    @State private var draft = ComposeDraft()

    @Namespace private var flowNamespace

    var body: some View {
        ZStack {
            Theme.Palette.canvas
                .ignoresSafeArea()

            tabContent
                .scaleEffect(isComposing ? 0.94 : 1)
                .blur(radius: isComposing ? 14 : 0)
                .opacity(isComposing ? 0 : 1)
                .allowsHitTesting(!isComposing)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    FloatingTabBar(
                        selection: $selectedTab,
                        flowNamespace: flowNamespace,
                        isCollapsed: isComposing,
                        onPrimaryAction: startComposing
                    )
                    .padding(.bottom, 4)
                }

            // Always in the hierarchy; it shows/hides its own contents so the
            // Next button can match-move with the FAB (see ComposeFlowView).
            ComposeFlowView(
                flowNamespace: flowNamespace,
                folderFrame: folderFrame,
                draft: draft,
                isPresented: isComposing,
                onClose: cancelComposing,
                onSave: file
            )
            .zIndex(1)
        }
        .environment(store)
        // The write step hides the status bar while typing (reference).
        .statusBarHidden(isComposing && draft.isEditingText)
        .onPreferenceChange(FolderFrameKey.self) { folderFrame = $0 }
        .sensoryFeedback(.success, trigger: store.count) { old, new in new > old }
    }

    @ViewBuilder
    private var tabContent: some View {
        ZStack {
            switch selectedTab {
            case .home:
                HomeView(
                    isFolderOpen: $isFolderOpen,
                    onSeeAll: { withAnimation(Theme.Motion.snappy) { selectedTab = .saved } }
                )
                .transition(.blurFade)
            case .saved:
                SavedView()
                    .transition(.blurFade)
            }
        }
    }

    // MARK: - Flow

    private func startComposing() {
        draft = ComposeDraft()
        withAnimation(Theme.Motion.smooth) { isComposing = true }
    }

    private func cancelComposing() {
        withAnimation(Theme.Motion.smooth) { isComposing = false }
    }

    /// Home-side choreography after a save (timings from the reference):
    /// 1. compose recedes, Home returns with the folder open (toggle off)
    /// 2. the note lands: chip drops into the centre slot, count rolls, new
    ///    row focus-pulls in at the top of Recent
    /// 3. the folder closes (toggle flips on)
    ///
    /// The in-flight fold itself (card folds in half and flies into
    /// `folderFrame`) will be layered on top of this in the 05/06 step.
    private func file(_ note: Note) {
        selectedTab = .home
        withAnimation(Theme.Motion.smooth) {
            isComposing = false
            isFolderOpen = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(420))
            withAnimation(Theme.Motion.bouncy) { store.add(note) }
            try? await Task.sleep(for: .milliseconds(380))
            withAnimation(Theme.Motion.snappy) { isFolderOpen = false }
        }
    }
}

#Preview {
    RootContainerView()
}
