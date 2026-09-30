import SwiftUI

/// 04_Write_a_chit
///
///   keyboard down                     keyboard up
///   ┌ nav ───────────────┐            (nav slides away, status bar hides)
///   What's on your                    What's on your
///   mind today?                       mind today?          ← rides up
///    ╭──────────╮ −3°                 ╭────────────╮ ×1.15, −1.5°
///    │ card     │                     │ card       │
///    ╰──────────╯                     ╰────────────╯
///                                          (→)             ← just above keys
///        (→)                          ▒▒▒ keyboard ▒▒▒
///
/// Layout flips from top-aligned (under the nav) to bottom-aligned (above the
/// Next button, which rides the keyboard) — the keyboard safe area does the
/// rest. The nav/Next themselves live in `ComposeFlowView`.
struct WriteStep: View {
    @Bindable var draft: ComposeDraft
    @FocusState private var isFocused: Bool
    @State private var hasEntered = false

    /// Focus lands this long after the step appears — the reference's tap on
    /// the card comes ≈0.87 s after Next (step settled ≈0.45 s, then a beat).
    private static let autoFocusDelay: Duration = .milliseconds(850)

    private var pose: NoteCardPose { draft.isEditingText ? .editing : .resting }

    var body: some View {
        VStack(spacing: 0) {
            // Two stacked lines, tight leading — same title style as step 1.
            VStack(spacing: -2.5) {
                Text("What’s on your")
                Text("mind today?")
            }
            .font(.softTitle)
            .tracking(-0.4)
            .foregroundStyle(Theme.Palette.ink)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            .padding(.top, 28.5)

            card
                // 65pt under the title (reference). While editing the ×1.2
                // growth is upward, so the visible gap shrinks.
                .padding(.top, 65)
                // Enters from the trailing edge, blurred (per reference).
                .offset(x: hasEntered ? 0 : 320)
                .blur(radius: hasEntered ? 0 : 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity,
               alignment: draft.isEditingText ? .bottom : .top)
        // While typing the nav is hidden (reference), so there must be a way
        // out: Done on the keyboard, or a tap anywhere outside the card.
        .contentShape(Rectangle())
        .onTapGesture { isFocused = false }
        .onChange(of: isFocused) { _, focused in
            withAnimation(Theme.Motion.keyboard) { draft.isEditingText = focused }
        }
        .task {
            withAnimation(Theme.Motion.smooth) { hasEntered = true }
            try? await Task.sleep(for: Self.autoFocusDelay)
            if !Task.isCancelled { isFocused = true }
        }
        .onDisappear { draft.isEditingText = false }
    }

    /// Enforces the cap (and strips Return) as the user types. Two SwiftUI
    /// pitfalls, both caught by `testTextCapAndFit`: truncating in `onChange`
    /// let fast typing slip past (67/60); clamping in the setter left the
    /// field *showing* 70 because the model value didn't change, so the field
    /// never re-rendered. So: accept the raw value, then clamp one tick later —
    /// the second change makes the field resync.
    private var textBinding: Binding<String> {
        Binding(
            get: { draft.text },
            set: { newValue in
                if newValue.contains(where: \.isNewline) { isFocused = false }   // Return = done
                let clean = ComposeDraft.sanitized(newValue)
                draft.text = newValue
                if clean != newValue {
                    DispatchQueue.main.async { draft.text = clean }
                }
            }
        )
    }

    private var card: some View {
        NoteCardView(pose: pose, content: NoteCardContent(
            icon: draft.icon,
            date: draft.createdAt,
            tag: draft.tag,
            onTagTap: { withAnimation(Theme.Motion.snappy) { draft.cycleTag() } }
        ) {
            TextField(
                "",
                text: textBinding,
                prompt: Text("Tap to write...")
                    .foregroundStyle(Theme.Palette.inkTertiary),
                axis: .vertical
            )
            .font(.softNoteText)
            .foregroundStyle(Theme.Palette.ink)
            .tint(Theme.Palette.amber)                          // amber caret
            .lineSpacing(NoteCardContent<EmptyView>.linePitch - 28.6)   // 24pt line ≈ 28.6
            .lineLimit(NoteCardContent<EmptyView>.maxLines)
            .submitLabel(.done)
            .focused($isFocused)
            .accessibilityIdentifier("noteText")
        })
        // Tapping anywhere on the card focuses the field (the reference taps it).
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
    }
}

#Preview {
    @Previewable @State var draft: ComposeDraft = {
        let d = ComposeDraft(); d.step = .write; return d
    }()
    WriteStep(draft: draft)
        .padding(.horizontal, 20)
        .background(Theme.Palette.canvas)
}
