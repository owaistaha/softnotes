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
///   ├─ ComposeFlowView (when composing)
///   └─ FoldStage — the save → fold overlay (full-screen, global space)
struct RootContainerView: View {
    @State private var store = NotesStore()
    @State private var selectedTab: AppTab = .home
    @State private var isComposing = false
    @State private var isFolderOpen = false
    @State private var folderFrame: CGRect = .zero
    /// Fresh for every compose session (see `startComposing`).
    @State private var draft = ComposeDraft()
    /// Save → fold progress; advanced ONLY by `save(_:)` (the timeline).
    @State private var foldPhase: FoldPhase = .idle
    /// What the fold overlay draws (nil = nothing folding).
    @State private var foldCard: FoldCard?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Namespace private var flowNamespace

    var body: some View {
        ZStack {
            Theme.Palette.canvas
                .ignoresSafeArea()

            tabContent
                .scaleEffect(isComposing && !reduceMotion ? 0.94 : 1)
                .blur(radius: isComposing && !reduceMotion ? 14 : 0)
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
                foldPhase: foldPhase,
                onClose: cancelComposing,
                onSave: save
            )
            .zIndex(1)

            // Always mounted: it animates its own progress values (see FoldStage).
            FoldStage(card: foldCard, phase: foldPhase)
                .zIndex(2)
        }
        .environment(store)
        // The write step hides the status bar while typing (reference).
        .statusBarHidden(isComposing && draft.isEditingText)
        .onPreferenceChange(FolderFrameKey.self) { folderFrame = $0 }
        .sensoryFeedback(.success, trigger: store.count) { old, new in new > old }
        .task { await runDemoFoldIfRequested() }
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

    /// 05 Save → 06 Fold: THE timeline — the only place `foldPhase` moves.
    /// Times are `FoldTimeline` (ms after the Next tap, from the reference),
    /// animations are `Theme.Motion`; the views derive everything else from
    /// the phase. Step 5A ends with the card folded on top of compose and
    /// then hands the note to `file(_:)`; 5B replaces that hand-off with the
    /// camera push and the drop into the folder.
    private func save(_ note: Note) {
        guard foldPhase == .idle, foldCard == nil else { return }
        if reduceMotion {
            fileWithCrossFade(note)
            return
        }
        let card = FoldCard(note: note, date: draft.createdAt, sourceFrame: draft.cardFrame,
                            sourcePose: draft.isEditingText ? .editing : .resting)
        let draft = draft

        Task { @MainActor in
            let clock = ContinuousClock()
            let start = clock.now
            func at(_ ms: Int) async { try? await clock.sleep(until: start + .milliseconds(ms)) }

            // Settle: the overlay takes the card exactly where it is (the
            // write step hides its own in the same frame), the keyboard drops,
            // the nav comes back, the card flies to the centre and straightens.
            withAnimation(Theme.Motion.settle) {
                foldCard = card
                foldPhase = .settle
                draft.isEditingText = false
            }
            await at(FoldTimeline.arcComplete)
            withAnimation(Theme.Motion.smooth) { draft.step = .save }   // arc 2/3 → full
            await at(FoldTimeline.lift)
            withAnimation(Theme.Motion.lift) { foldPhase = .lift }
            await at(FoldTimeline.clear)
            withAnimation(Theme.Motion.clear) { foldPhase = .clear }
            await at(FoldTimeline.fold)
            withAnimation(Theme.Motion.fold) { foldPhase = .fold }
            await at(FoldTimeline.folded)
            foldPhase = .folded

            // 5A hand-off: Home files the note; the folded card fades out.
            await at(FoldTimeline.handOff)
            file(note)
            withAnimation(Theme.Motion.crossFade) { foldCard = nil }
            try? await Task.sleep(for: .seconds(FoldTimeline.reducedDuration + 0.05))
            foldPhase = .idle                   // no animation: nothing is drawn now
        }
    }

    /// Reduce Motion: no flight, no fold — compose cross-fades to Home and the
    /// note is simply there (the count still rolls).
    private func fileWithCrossFade(_ note: Note) {
        selectedTab = .home
        draft.isEditingText = false
        withAnimation(Theme.Motion.crossFade) {
            isComposing = false
            store.add(note)
        }
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

// MARK: - DEBUG launch arguments

extension RootContainerView {
    /// `-demoFold`: opens compose on the write step with "Have a good day"
    /// typed, waits for the keyboard (auto-focus), then runs the save → fold
    /// timeline exactly as Next would — for recording without typing.
    private func runDemoFoldIfRequested() async {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("-demoFold") else { return }
        try? await Task.sleep(for: .milliseconds(600))
        startComposing()
        draft.step = .write
        draft.text = "Have a good day"
        // Write step enters, auto-focuses at 0.85 s, keyboard ≈0.5 s later.
        try? await Task.sleep(for: .milliseconds(2600))
        save(draft.makeNote())
        #endif
    }
}

#Preview {
    RootContainerView()
}
