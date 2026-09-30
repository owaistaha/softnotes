import SwiftUI

/// The app shell. Owns everything that has to be coordinated *across* screens:
///
/// • the store and the selected tab
/// • the compose flow, presented as an in-place overlay (not a sheet) so the
///   FAB can morph into its Next button and the saved note can fly back
///   into the Home folder
/// • the folder's on-screen frame (via `FolderFrameKey`) and its open state
/// • THE save timeline (`save(_:)`) and the flight overlay
///
///   ZStack
///   ├─ canvas
///   ├─ tab content (Home | Saved) ── recedes while composing; zooms ×1.3 on
///   │    │                           the folder and rises into view on save
///   │    └─ safeAreaInset(bottom): FloatingTabBar (+ FAB)
///   ├─ ComposeFlowView (when composing)
///   └─ FoldStage — the save flight (full-screen, global space, above both)
struct RootContainerView: View {
    @State private var store = NotesStore()
    @State private var selectedTab: AppTab = .home
    @State private var isComposing = false
    @State private var isFolderOpen = false
    /// Frozen while composing/saving (Home is transformed then): the folder's
    /// and Home's untransformed global frames, and the screen size.
    @State private var folderFrame: CGRect = .zero
    @State private var homeFrame: CGRect = .zero
    @State private var screenSize: CGSize = .zero
    /// Fresh for every compose session (see `startComposing`).
    @State private var draft = ComposeDraft()

    // Save sequence — advanced ONLY by `save(_:)` (the timeline).
    @State private var foldPhase: FoldPhase = .idle
    /// What the flight draws (nil = nothing in flight).
    @State private var foldCard: FoldCard?
    /// Where the flight lands (set when Home is set up, at `.folded`).
    @State private var landing: FoldLanding?
    /// The note in flight, until it lands (for a clean fast-forward).
    @State private var pendingNote: Note?
    /// Its chip appears in place (no drop-in) — the flying icon becomes it.
    @State private var landingNoteID: Note.ID?
    /// Recent holds the new row back until `rowEntry` (reference: it arrives
    /// ≈1.8 s after the landing, after the zoom-out).
    @State private var heldNoteID: Note.ID?
    /// The count bubble reads one ahead of the store from `countRoll` until
    /// the landing (reference: the count rolls just before the icon settles).
    @State private var countLead = 0
    @State private var saveTask: Task<Void, Never>?
    /// DEBUG `-keyboardCycles`: the watchdog's summary once the cycles finish.
    @State private var keyboardCycleReport: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    @Namespace private var flowNamespace

    /// Reference: during the push the folder is shown ×1.30 its Home size
    /// (front panel 0.565 → 0.732 of the screen width), centre chip at 0.549
    /// of the screen height. Home enters from fully below the screen (its
    /// first pixels show ≈50 ms after the card starts rising); 308pt left the
    /// zoomed chips on screen in the first frame, so 500.
    private static let homeZoom: CGFloat = 1.3
    private static let zoomedChipY: CGFloat = 0.549
    private static let homeRise: CGFloat = 500
    /// The folded card rises this much while Home comes up (ref 156pt @ 852).
    private static let cardRise: CGFloat = 160

    var body: some View {
        ZStack {
            Theme.Palette.canvas
                .ignoresSafeArea()
                // Full screen, whether or not the proxy reports the safe-area
                // insets separately (on iOS 26 it gives the inset size).
                .onGeometryChange(for: CGSize.self) { proxy in
                    let frame = proxy.frame(in: .global)
                    return CGSize(width: frame.maxX + proxy.safeAreaInsets.trailing,
                                  height: frame.maxY + proxy.safeAreaInsets.bottom)
                } action: { size in
                    if canMeasureHome && size != screenSize { screenSize = size }
                }

            tabContent
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                    if canMeasureHome && frame != homeFrame { homeFrame = frame }
                }
                // Hidden under compose until the push; shown instantly then
                // (it enters from below the screen, not by fading).
                .opacity(homeHiddenForSave ? 0 : 1)
                .transaction(value: homeHiddenForSave) { $0.animation = nil }
                .scaleEffect(homeTransform.scale, anchor: .topLeading)
                .offset(homeTransform.offset)
                .blur(radius: isComposing && !reduceMotion ? 14 : 0)
                .opacity(isComposing ? 0 : 1)
                .allowsHitTesting(!isComposing && foldPhase == .idle)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    FloatingTabBar(
                        selection: $selectedTab,
                        flowNamespace: flowNamespace,
                        isCollapsed: isComposing,
                        onPrimaryAction: startComposing
                    )
                    .padding(.bottom, 4)
                    // Hidden during the push; comes back with the zoom-out.
                    // The FAB was re-inserted while this was invisible, so it
                    // just fades in with the bar — no morph, no dip.
                    .opacity(chromeHidden ? 0 : 1)
                    .blur(radius: chromeHidden ? 8 : 0)
                    .offset(y: chromeHidden ? 24 : 0)
                    .animation(Theme.Motion.chromeIn, value: chromeHidden)
                    .allowsHitTesting(foldPhase == .idle)
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
            FoldStage(card: foldCard, phase: foldPhase, landing: landing)
                .zIndex(2)

            // Exists only while a save is in flight — VoiceOver reads
            // "Saving note"; UI tests check nothing is left behind.
            if foldPhase != .idle || foldCard != nil {
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityElement()
                    .accessibilityLabel("Saving note")
                    .accessibilityIdentifier("saveInFlight")
                    .allowsHitTesting(false)
            }
        }
        .environment(store)
        // The write step hides the status bar while typing (reference).
        .statusBarHidden(isComposing && draft.isEditingText)
        .onPreferenceChange(FolderFrameKey.self) { frame in
            if canMeasureHome && frame != folderFrame { folderFrame = frame }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { finishSaveNow() }
        }
        .sensoryFeedback(.success, trigger: store.count) { old, new in new > old }
        .task { await runDemoFoldIfRequested() }
        .task { await runKeyboardCyclesIfRequested() }
        #if DEBUG
        .task {
            // `-watchdog`: log main-thread stalls > 500 ms for the whole run
            // (os_log subsystem com.owaistaha.softnotes, category watchdog).
            if ProcessInfo.processInfo.arguments.contains("-watchdog") { MainThreadWatchdog.shared.start() }
        }
        #endif
        #if DEBUG
        .background {
            // `-keyboardCycles`: log SwiftUI's keyboard safe-area edge next to
            // UIKit's keyboard top (the discrepancy KeyboardOverlapPadding
            // exists for; measured per iOS version).
            if ProcessInfo.processInfo.arguments.contains("-keyboardCycles") {
                GeometryReader { proxy in
                    Color.clear
                        .onChange(of: proxy.frame(in: .global).maxY.rounded(), initial: true) { _, maxY in
                            print("KEYBOARD PROBE: SwiftUI safe-area bottom \(maxY)")
                        }
                }
                    .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
                        let frame = (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect) ?? .zero
                        let duration = note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] ?? "-"
                        let curve = note.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] ?? "-"
                        print("KEYBOARD PROBE: UIKit keyboard top \(frame.minY) duration \(duration) curve \(curve) t=\(MainThreadWatchdog.clock())")
                    }
            }
        }
        .overlay(alignment: .topLeading) {
            if let keyboardCycleReport {
                Color.clear.frame(width: 1, height: 1)
                    .accessibilityElement()
                    .accessibilityLabel(keyboardCycleReport)
                    .accessibilityIdentifier("keyboardCycleReport")
            }
        }
        #endif
    }

    @ViewBuilder
    private var tabContent: some View {
        ZStack {
            switch selectedTab {
            case .home:
                HomeView(
                    isFolderOpen: $isFolderOpen,
                    showsChrome: !chromeHidden,
                    heldNoteID: heldNoteID,
                    landingNoteID: landingNoteID,
                    // Set up with the rest of Home at `.folded`, out of sight: shuffled
                    // during the push, the leaving right chip showed as Home rose.
                    vacatesCentreChip: foldPhase >= .folded && foldPhase < .landed,
                    countLead: countLead,
                    onSeeAll: { withAnimation(Theme.Motion.snappy) { selectedTab = .saved } }
                )
                .transition(.blurFade)
            case .saved:
                SavedView()
                    .transition(.blurFade)
            }
        }
    }

    // MARK: - Home presentation (derived from the phase)

    /// Home's frames are only measured while it's untransformed.
    private var canMeasureHome: Bool { !isComposing && foldPhase == .idle }

    /// Between the tap and the push Home is out of sight (compose, then the
    /// folding card on an empty canvas).
    private var homeHiddenForSave: Bool { foldPhase >= .settle && foldPhase < .push }

    /// Header, Recent and tab bar are hidden while Home is zoomed on the folder.
    private var chromeHidden: Bool { foldPhase >= .folded && foldPhase < .zoomOut }

    private var homeTransform: (scale: CGFloat, offset: CGSize) {
        if foldPhase >= .folded && foldPhase < .zoomOut {
            let zoom = homeZoomTransform
            let rise = foldPhase >= .push ? 0 : Self.homeRise
            return (zoom.scale, CGSize(width: zoom.offset.width, height: zoom.offset.height + rise))
        }
        if isComposing && !reduceMotion {
            // Recede: ×0.94 about Home's centre, expressed about its top-left.
            let scale: CGFloat = 0.94
            return (scale, CGSize(width: homeFrame.width * (1 - scale) / 2,
                                  height: homeFrame.height * (1 - scale) / 2))
        }
        return (1, .zero)
    }

    /// Home zoomed ×1.3 so the centre chip slot lands where the reference has
    /// it; applied as scale about Home's top-left + offset.
    private var homeZoomTransform: (scale: CGFloat, offset: CGSize) {
        let scale = Self.homeZoom
        let origin = homeFrame.origin
        let chip = FolderCard.chipCenter(0, in: folderFrame, isOpen: false)
        let target = CGPoint(x: chip.x, y: screenSize.height * Self.zoomedChipY)
        return (scale, CGSize(width: target.x - origin.x - scale * (chip.x - origin.x),
                              height: target.y - origin.y - scale * (chip.y - origin.y)))
    }

    /// A point of untransformed Home (global) → where it's drawn when zoomed and risen.
    private func zoomed(_ point: CGPoint) -> CGPoint {
        let zoom = homeZoomTransform
        let origin = homeFrame.origin
        return CGPoint(x: origin.x + zoom.scale * (point.x - origin.x) + zoom.offset.width,
                       y: origin.y + zoom.scale * (point.y - origin.y) + zoom.offset.height)
    }

    /// Landing geometry, computed from `FolderCard`'s static geometry and the
    /// zoom — not guessed.
    private func makeLanding(for note: Note) -> FoldLanding {
        let scale = Self.homeZoom
        let panel = FolderCard.frontPanelFrame(in: folderFrame)
        let panelOrigin = zoomed(panel.origin)
        return FoldLanding(
            rise: Self.cardRise,
            chipCenter: zoomed(FolderCard.chipCenter(0, in: folderFrame, isOpen: true,
                                                     floatStart: !reduceMotion)),
            chipSize: FolderCard.chipSize * scale,
            chipCornerFraction: note.icon.shape == .circle ? 0.5 : StackedIconView.squircleCorner,
            frontPanel: CGRect(origin: panelOrigin,
                               size: CGSize(width: panel.width * scale, height: panel.height * scale)),
            zoom: scale
        )
    }

    // MARK: - Flow

    private func startComposing() {
        guard foldPhase == .idle else { return }
        draft = ComposeDraft()
        withAnimation(Theme.Motion.smooth) { isComposing = true }
    }

    private func cancelComposing() {
        withAnimation(Theme.Motion.smooth) { isComposing = false }
    }

    /// 05 Save → 06 Fold → 07 File it away: THE timeline — the only place
    /// `foldPhase` moves. Times are `FoldTimeline` (ms after the Next tap,
    /// from the reference), animations are `Theme.Motion`; every view derives
    /// its look from the phase. Nothing on Home changes in the store until the
    /// icon reaches the chip slot.
    private func save(_ note: Note) {
        guard foldPhase == .idle, saveTask == nil else { return }
        if reduceMotion {
            fileWithCrossFade(note)
            return
        }
        let card = FoldCard(note: note, date: draft.createdAt, sourceFrame: draft.cardFrame,
                            sourcePose: draft.isEditingText ? .editing : .resting)
        let draft = draft
        pendingNote = note

        saveTask = Task { @MainActor in
            let clock = ContinuousClock()
            let start = clock.now
            func at(_ ms: Int) async throws { try await clock.sleep(until: start + .milliseconds(ms)) }
            var instantly = Transaction()
            instantly.disablesAnimations = true

            do {
                // 05 — the overlay takes the card exactly where it is (the
                // write step hides its own in the same frame), the keyboard
                // drops, the nav comes back, the card flies to the centre.
                withAnimation(Theme.Motion.settle) {
                    foldCard = card
                    foldPhase = .settle
                    draft.isEditingText = false
                }
                try await at(FoldTimeline.arcComplete)
                withAnimation(Theme.Motion.smooth) { draft.step = .save }   // arc 2/3 → full
                try await at(FoldTimeline.lift)
                withAnimation(Theme.Motion.lift) { foldPhase = .lift }
                try await at(FoldTimeline.clear)
                withAnimation(Theme.Motion.clear) { foldPhase = .clear }

                // 06 — fold.
                try await at(FoldTimeline.fold)
                withAnimation(Theme.Motion.fold) { foldPhase = .fold }

                // Out of sight: compose goes (its UI is already cleared), the
                // FAB returns inside the hidden tab bar, and Home is set up
                // zoomed on the folder, below the screen, folder open, with
                // the OLD count and chips.
                try await at(FoldTimeline.folded)
                withTransaction(instantly) {
                    selectedTab = .home
                    landing = makeLanding(for: note)
                    isFolderOpen = true
                    isComposing = false
                    foldPhase = .folded
                }

                try await at(FoldTimeline.push)
                withAnimation(Theme.Motion.push) { foldPhase = .push }
                try await at(FoldTimeline.pushStep)
                withAnimation(Theme.Motion.pushStep) { foldPhase = .pushStep }

                // Card behind the front panel, icon into the chip slot. The
                // landing waits for the drop to *finish*, so the icon is
                // exactly on the slot in the frame the chip replaces it.
                try await at(FoldTimeline.drop)
                let dropFinished = Task { @MainActor in
                    await withCheckedContinuation { done in
                        withAnimation(Theme.Motion.dropIn, completionCriteria: .logicallyComplete) {
                            foldPhase = .drop
                        } completion: { done.resume() }
                    }
                }
                // The count rolls (and the folder bounces) just before the
                // icon settles — the store still holds the old notes.
                try await at(FoldTimeline.countRoll)
                withAnimation(Theme.Motion.snappy) { countLead = 1 }
                await dropFinished.value
                try Task.checkCancellation()

                // 07 — the icon becomes the centre chip: the note is added
                // (count rolls, chips shuffle, folder bounces); the new row is
                // held back from Recent for now.
                withAnimation(Theme.Motion.bouncy) {
                    store.add(note)
                    countLead = 0
                    pendingNote = nil
                    landingNoteID = note.id
                    heldNoteID = note.id
                    foldCard = nil
                    foldPhase = .landed
                }
                try await clock.sleep(for: .milliseconds(FoldTimeline.closeAfterLanding))
                withAnimation(Theme.Motion.snappy) {
                    isFolderOpen = false
                    foldPhase = .close
                }
                try await at(FoldTimeline.zoomOut)
                withAnimation(Theme.Motion.zoomOut) { foldPhase = .zoomOut }
                try await at(FoldTimeline.rowEntry)
                withAnimation(Theme.Motion.bouncy) {
                    heldNoteID = nil
                    foldPhase = .rowEntry
                }
                try await at(FoldTimeline.done)
                withTransaction(instantly) {
                    foldPhase = .idle
                    landing = nil
                    landingNoteID = nil
                }
                saveTask = nil
            } catch {
                // Cancelled: `finishSaveNow()` has already put everything in
                // its end state.
            }
        }
    }

    /// Jumps the save to its end state without animation — the app went to
    /// the background mid-flight. The note is added exactly once (unless it
    /// already landed), nothing is left in flight or held back.
    private func finishSaveNow() {
        guard let task = saveTask else { return }
        task.cancel()
        saveTask = nil
        var instantly = Transaction()
        instantly.disablesAnimations = true
        withTransaction(instantly) {
            if let note = pendingNote { store.add(note) }
            pendingNote = nil
            countLead = 0
            selectedTab = .home
            isComposing = false
            isFolderOpen = false
            draft.isEditingText = false
            foldCard = nil
            landing = nil
            landingNoteID = nil
            heldNoteID = nil
            foldPhase = .idle
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
}

// MARK: - DEBUG launch arguments

extension RootContainerView {
    /// `-keyboardCycles N`: opens the write step and focuses / dismisses the
    /// card N times (keyboard up 1.2 s, down 1.0 s) with the main-thread
    /// watchdog running; no XCUITest queries happen meanwhile. Prints one line
    /// per cycle and publishes the summary as the `keyboardCycleReport`
    /// accessibility element.
    private func runKeyboardCyclesIfRequested() async {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-keyboardCycles"), i + 1 < args.count,
              let cycles = Int(args[i + 1]) else { return }
        let watchdog = MainThreadWatchdog.shared
        watchdog.start()
        try? await Task.sleep(for: .milliseconds(600))
        print("HARNESS t=\(MainThreadWatchdog.clock()) ms: open compose on the write step")
        startComposing()
        draft.step = .write
        // Auto-focus at 0.85 s; let the first keyboard settle. Stalls in this
        // first open (compose + first keyboard) are counted too.
        try? await Task.sleep(for: .milliseconds(2500))
        print("KEYBOARD FIRST OPEN: \(watchdog.report)")
        for cycle in 1...cycles {
            let before = watchdog.report.stalls.count
            NotificationCenter.default.post(name: .debugWriteFocus, object: false)
            try? await Task.sleep(for: .milliseconds(1000))
            NotificationCenter.default.post(name: .debugWriteFocus, object: true)
            try? await Task.sleep(for: .milliseconds(1200))
            let r = watchdog.report
            print("KEYBOARD CYCLE \(cycle)/\(cycles): stalls +\(r.stalls.count - before), max so far \(r.maxLatency) ms")
        }
        let report = "cycles=\(cycles) \(watchdog.report)"
        print("KEYBOARD CYCLES DONE: \(report)")
        keyboardCycleReport = report
        #endif
    }

    /// `-demoFold`: opens compose on the write step with "Have a good day"
    /// typed, waits for the keyboard (auto-focus), then runs the whole save
    /// sequence exactly as Next would — for recording without typing.
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
