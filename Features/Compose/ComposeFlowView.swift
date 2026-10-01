import SwiftUI

/// The compose flow's shell: nav bar + the current step + the Next button.
///
/// • Each step is its own view, swapped with `.blurFade`.
/// • The nav bar and Next button live here (not in the steps) so they persist
///   across steps; Next's amber arc advances 1/3 → 2/3.
/// • The Next button is the Home FAB morphed via matched geometry. It is kept
///   *outside* the blur-fading content and uses `.identity` transitions (as
///   does the FAB), so the black disc glides solid instead of dissolving.
/// • This view stays in the hierarchy permanently; `isPresented` toggles its
///   contents, which lets the button match-move with the FAB in one transaction.
struct ComposeFlowView: View {
    let flowNamespace: Namespace.ID
    /// Global frame of the Home folder card — the fold animation's target (Step 5).
    let folderFrame: CGRect
    let draft: ComposeDraft
    let isPresented: Bool
    /// Save/fold progress, driven by the container's timeline (read-only here):
    /// the nav comes back as the keyboard drops, then at `.clear` the nav
    /// blurs away and Next drops off the bottom.
    var foldPhase: FoldPhase = .idle
    var onClose: () -> Void
    var onSave: (Note) -> Void

    var body: some View {
        ZStack {
            if isPresented {
                VStack(spacing: 0) {
                    ComposeNavBar(
                        step: draft.visibleStepNumber,
                        totalSteps: ComposeDraft.visibleStepCount,
                        onBack: back,
                        onClose: onClose
                    )
                    // While typing, the nav slides up and away (reference);
                    // on save it blurs away with the title.
                    .offset(y: draft.isEditingText ? -110 : isClearing ? -12 : 0)
                    .opacity(draft.isEditingText || isClearing ? 0 : 1)
                    .blur(radius: isClearing ? 8 : 0)
                    .allowsHitTesting(!draft.isEditingText)

                    ZStack {
                        switch draft.step {
                        case .pickIcon:
                            IconPickerStep(draft: draft).transition(.blurFade)
                        case .write, .save:
                            WriteStep(draft: draft, foldPhase: foldPhase).transition(.blurFade)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                    // Room for the Next button, which is drawn in its own layer below.
                    Color.clear.frame(height: PrimaryActionButton.outerDiameter + nextBottomGap
                                      + (draft.isEditingText ? Self.cardToNextGap : 0))
                }
                .padding(.horizontal, Theme.Metrics.screenPadding)
                .transition(.blurFade)

                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    PrimaryActionButton(
                        symbol: "arrow.right",
                        progress: draft.progress,
                        haloFill: Theme.Palette.surface,
                        accessibilityLabel: "Next",
                        action: next
                    )
                    .disabled(!nextEnabled)
                    .opacity(nextLooksEnabled ? 1 : 0.35)
                    .animation(Theme.Motion.snappy, value: nextLooksEnabled)
                    .matchedGeometryEffect(id: FlowID.primaryAction, in: flowNamespace)
                    .padding(.bottom, nextBottomGap)
                    // Save: Next drops off the bottom edge, blurring, still
                    // dark (reference: half off-screen after ≈70 ms, gone ≈120).
                    .blur(radius: isClearing ? 4 : 0)
                    .offset(y: isClearing ? 150 : 0)
                    .animation(Theme.Motion.drop, value: isClearing)
                }
                // See `PrimaryActionButton.morphTransition` — must sit on the
                // view that is actually inserted/removed (this container).
                .transition(PrimaryActionButton.morphTransition)
            }
        }
        .keyboardOverlapPadding()
        // Nothing is tappable once the save sequence has started.
        .allowsHitTesting(isPresented && foldPhase == .idle)
    }

    private var isClearing: Bool { foldPhase >= .clear }

    /// Next sits 4pt above the home indicator area normally, and 17pt above
    /// the keyboard while typing: its centre ≈55pt above the keys' visible
    /// top, as in the reference. (Was 22 while the keyboard padding
    /// overflowed and shifted the layout — see KeyboardOverlapPadding.)
    private var nextBottomGap: CGFloat { draft.isEditingText ? 17 : 4 }
    /// Reference: ≈17pt between the (grown) card and the Next halo.
    private static let cardToNextGap: CGFloat = 17

    // MARK: - Actions

    private func back() {
        if draft.step == .pickIcon {
            onClose()                                   // Back on step 1 closes the flow
        } else {
            withAnimation(Theme.Motion.smooth) { _ = draft.goBack() }
        }
    }

    private func next() {
        switch draft.step {
        case .pickIcon:
            withAnimation(Theme.Motion.smooth) { _ = draft.advance() }
        case .write:
            // Hands the note to the container, which runs the save → fold
            // timeline (and then files it on Home).
            if draft.canAdvance {
                onSave(draft.makeNote())
            } else if Self.demoSaveEnabled {
                onSave(demoNote())
            }
        case .save:
            break
        }
    }

    private var nextEnabled: Bool {
        draft.step == .write ? (draft.canAdvance || Self.demoSaveEnabled) : draft.canAdvance
    }

    /// During the save phase Next can't be tapped but keeps its full colour
    /// (its arc completing is part of the sequence).
    private var nextLooksEnabled: Bool { nextEnabled || draft.step == .save }

    /// DEBUG-only launch argument `-demoSave`: Next on the write step files a
    /// demo note (with the icon picked in step 1) so Home's save choreography
    /// can still be exercised before the real fold exists.
    private static var demoSaveEnabled: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-demoSave")
        #else
        false
        #endif
    }

    private func demoNote() -> Note {
        var note = Note.demo()
        note.icon = draft.icon
        return note
    }
}

// MARK: - Nav bar

struct ComposeNavBar: View {
    let step: Int
    let totalSteps: Int
    var onBack: () -> Void
    var onClose: () -> Void

    var body: some View {
        HStack {
            // Back is a raised white disc, close a flat grey one (per reference).
            circleButton("chevron.left", label: "Back", id: "composeBack", raised: true, action: onBack)
            Spacer()
            VStack(spacing: 2) {
                Text("New note")
                    .softFont(.section)
                    .foregroundStyle(Theme.Palette.ink)
                Text("Step \(step) of \(totalSteps)")
                    .softFont(.navSubtitle)
                    .foregroundStyle(Theme.Palette.inkSecondary)
                    .contentTransition(.numericText(value: Double(step)))
            }
            Spacer()
            circleButton("xmark", label: "Close", id: "composeClose", raised: false, action: onClose)
        }
    }

    private func circleButton(
        _ symbol: String, label: String, id: String, raised: Bool, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.Palette.ink)
                .frame(width: Theme.Metrics.navButton, height: Theme.Metrics.navButton)
                .background {
                    if raised {
                        SoftSurface(Circle(), elevation: .raised)
                    } else {
                        Circle().fill(Theme.Palette.track)
                    }
                }
        }
        .buttonStyle(.pressable(scale: 0.9))
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }
}

#Preview {
    @Previewable @Namespace var ns
    ComposeFlowView(
        flowNamespace: ns, folderFrame: .zero, draft: ComposeDraft(),
        isPresented: true, onClose: {}, onSave: { _ in }
    )
    .background(Theme.Palette.canvas)
}
