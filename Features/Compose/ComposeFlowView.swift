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

                    ZStack {
                        switch draft.step {
                        case .pickIcon:
                            IconPickerStep(draft: draft).transition(.blurFade)
                        case .write, .save:
                            WriteStep(draft: draft).transition(.blurFade)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                    // Room for the Next button, which is drawn in its own layer below.
                    Color.clear.frame(height: PrimaryActionButton.outerDiameter + 4)
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
                    .opacity(nextEnabled ? 1 : 0.35)
                    .animation(Theme.Motion.snappy, value: nextEnabled)
                    .matchedGeometryEffect(id: FlowID.primaryAction, in: flowNamespace)
                    .padding(.bottom, 4)
                }
                // See `PrimaryActionButton.morphTransition` — must sit on the
                // view that is actually inserted/removed (this container).
                .transition(PrimaryActionButton.morphTransition)
            }
        }
        .allowsHitTesting(isPresented)
    }

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
            // Step 5 replaces this with the real save → fold → file-away.
            if Self.demoSaveEnabled { onSave(demoNote()) }
        case .save:
            break
        }
    }

    private var nextEnabled: Bool {
        draft.step == .write ? (draft.canAdvance || Self.demoSaveEnabled) : draft.canAdvance
    }

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
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.Palette.ink)
                Text("Step \(step) of \(totalSteps)")
                    .font(.system(size: 12))
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
