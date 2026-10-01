import SwiftUI

/// The note, open on its paper card — an in-place overlay owned by
/// `RootContainerView` (like compose: no sheet, so the icon and card can fly
/// from the row they came from).
///
///   ‹ back        Note            ♡  🗑      ← nav: back, title, Save toggle, Delete
///                                              (slides away while typing, like compose)
///        ╭────────────╮ −3°
///        │ ◈ Morning… │      tap the icon → picker grid (IconPickerStep)
///        │ text       │      tap the text → keyboard, 48-character cap
///        │ [#daily]   │      tap the chip → next tag
///        ╰────────────╯
///
/// Opening / closing — ONE progress value `t` (0 = at the row, 1 = open):
/// • the card grows from the row: scale `startScale` → 1 and its centre moves
///   so that its header-icon slot starts exactly on the row's icon;
/// • the icon is ONE view (`FlightIcon`, Animatable in `t`) travelling from the
///   row icon (40pt) to the header slot (32pt, −3°); the card's own header
///   icon is hidden meanwhile and swaps in, in the same frame, when the flight
///   ends (and the other way round on close);
/// • positions come from measured frames (the row's, the card's), never guessed;
/// • Reduce Motion, or no row to return to (unsaved on the Saved tab, deleted):
///   a plain 0.25 s cross-fade.
///
/// Edits go to `NotesStore.update` as they happen (debounced like every other
/// mutation). Empty text on leaving the field restores the stored text; the
/// note is never deleted by editing.
struct NoteDetailView: View {
    let noteID: Note.ID
    /// The edit buffer (icon, text, tag, keyboard flag) — see `ComposeDraft(editing:)`.
    @Bindable var draft: ComposeDraft
    /// The tapped row's global frame.
    let sourceFrame: CGRect
    /// The grow/shrink from the row is used (false: Reduce Motion or unknown row).
    let flies: Bool
    /// Is the row still in the list the note was opened from? (Closing flies
    /// back only if so — an unsaved note vanishes from the Saved tab.)
    var returnsToRow: () -> Bool
    var onClose: () -> Void

    @Environment(NotesStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 0 = at the row (closed), 1 = open. Animated by `Theme.Motion`.
    @State private var t: Double = 0
    @State private var usesFlight: Bool
    /// The flying icon is drawn (and the card's own header icon hidden).
    @State private var iconInFlight = true
    /// Open and at rest: controls respond.
    @State private var settled = false
    @State private var hasOpened = false
    @State private var cardFrame: CGRect = .zero
    @State private var isPickingIcon = false
    @State private var confirmingDelete = false
    @State private var isDeleting = false
    /// The note's text when the field got focus — what "discard the edit" brings back.
    @State private var textBeforeEditing = ""
    @FocusState private var isFocused: Bool
    @AccessibilityFocusState private var titleFocused: Bool

    private typealias Card = NoteCardContent<NoteCardStaticText>

    /// The card starts this big, centred so its header icon sits on the row's icon.
    static let startScale: CGFloat = 0.3
    private static let rowIconSize: CGFloat = 40
    private static let restingRotation: Double = -3
    /// Gap between the card's bottom and the keyboard while typing.
    private static let editingBottomGap: CGFloat = 24

    init(noteID: Note.ID, draft: ComposeDraft, sourceFrame: CGRect, flies: Bool,
         returnsToRow: @escaping () -> Bool, onClose: @escaping () -> Void) {
        self.noteID = noteID
        self.draft = draft
        self.sourceFrame = sourceFrame
        self.flies = flies
        self.returnsToRow = returnsToRow
        self.onClose = onClose
        _usesFlight = State(initialValue: flies)
    }

    private var isSaved: Bool { store.note(withID: noteID)?.isSaved ?? false }
    private var isTyping: Bool { draft.isEditingText }

    // MARK: Body

    var body: some View {
        ZStack {
            // Home stays underneath; the canvas fades in over it.
            Theme.Palette.canvas
                .ignoresSafeArea()
                .opacity(t)

            VStack(spacing: 0) {
                nav
                    .offset(y: isTyping ? -110 : 0)
                    .opacity(isTyping ? 0 : t)
                    .allowsHitTesting(settled && !isTyping && !isDeleting)

                ZStack {
                    if isPickingIcon {
                        IconPickerStep(draft: draft)
                            .transition(.blurFade)
                    } else {
                        cardArea
                            .transition(.blurFade)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .padding(.horizontal, Theme.Metrics.screenPadding)
            .keyboardOverlapPadding()
            .allowsHitTesting(settled)

            // The travelling icon (one view) — above everything while it flies.
            GeometryReader { proxy in
                if usesFlight && iconInFlight && cardFrame != .zero {
                    FlightIcon(icon: draft.icon, t: t, from: rowIconCenter, to: finalIconCenter,
                               origin: proxy.frame(in: .global).origin)
                } else if usesFlight && iconInFlight {
                    // Before the card is measured: the icon sits on the row's icon.
                    FlightIcon(icon: draft.icon, t: 0, from: rowIconCenter, to: rowIconCenter,
                               origin: proxy.frame(in: .global).origin)
                }
            }
            .allowsHitTesting(false)
        }
        .confirmationDialog("Delete this note?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete note", role: .destructive, action: deleteNote)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This can’t be undone.")
        }
        .onChange(of: draft.text) { _, new in
            // Nothing typed and not in the field any more (Return, tap outside): discard
            // the edit. (Also catches the cap logic's one-tick-later clean-up write.)
            if !isFocused && isBlank(new) { restoreTextIfEmpty() } else { commitText(ComposeDraft.sanitized(new)) }
        }
        .onChange(of: draft.icon) { _, new in store.update(noteID) { $0.icon = new } }
        .onChange(of: draft.tags) { _, new in store.update(noteID) { $0.tags = new } }
        .onChange(of: isFocused) { _, focused in
            if focused { textBeforeEditing = storedText() }
            withAnimation(Theme.Motion.keyboard) { draft.isEditingText = focused }
            if !focused { restoreTextIfEmpty() }
        }
        .onDisappear { draft.isEditingText = false }
        .accessibilityAddTraits(.isModal)
    }

    // MARK: Nav

    private var nav: some View {
        HStack(spacing: 10) {
            CircleNavButton(symbol: "chevron.left", label: "Back", id: "detailBack", raised: true, action: back)
            Spacer(minLength: 0)
            if !isPickingIcon {
                CircleNavButton(
                    symbol: isSaved ? "heart.fill" : "heart",
                    label: "Saved", id: "detailSave", raised: true,
                    tint: isSaved ? PastelTone.pink.base : nil,
                    traits: .isToggle, value: isSaved ? "On" : "Off",
                    hint: "Keeps this note in Saved",
                    action: toggleSaved
                )
                CircleNavButton(
                    symbol: "trash", label: "Delete", id: "detailDelete", raised: false,
                    hint: "Deletes this note. You will be asked to confirm.",
                    action: { confirmingDelete = true }
                )
            }
        }
        .frame(height: Theme.Metrics.navButton)
        .overlay {
            VStack(spacing: 2) {
                Text(isPickingIcon ? "Icon" : "Note")
                    .font(.softSection)
                    .foregroundStyle(Theme.Palette.ink)
                Text(isPickingIcon ? "Pick one for this note" : "Tap the text to edit")
                    .font(.softCaption)
                    .foregroundStyle(Theme.Palette.inkSecondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            .accessibilityFocused($titleFocused)
            .allowsHitTesting(false)
        }
    }

    // MARK: Card

    private var cardArea: some View {
        card
            .onGeometryChange(for: CGRect.self) { proxy in
                let f = proxy.frame(in: .global)
                return CGRect(x: f.minX.rounded(), y: f.minY.rounded(), width: f.width.rounded(), height: f.height.rounded())
            } action: { frame in
                if frame != cardFrame { cardFrame = frame }
                openIfNeeded(measured: frame)
            }
            .scaleEffect(cardScale)
            .offset(cardOffset)
            .opacity(t)
            .frame(maxWidth: .infinity, maxHeight: .infinity,
                   alignment: isTyping ? .bottom : .center)
            .padding(.bottom, isTyping ? Self.editingBottomGap : 40)
            .contentShape(Rectangle())
            .onTapGesture { isFocused = false }
    }

    private var card: some View {
        NoteCardView(pose: isTyping ? .editing : .resting, content: NoteCardContent(
            icon: draft.icon,
            date: draft.createdAt,
            tag: draft.tag,
            onTagTap: { withAnimation(Theme.Motion.snappy) { draft.cycleTag() } },
            onIconTap: { openPicker() },
            showsHeaderIcon: !(usesFlight && iconInFlight)
        ) {
            TextField(
                "",
                text: textBinding,
                prompt: Text("Tap to write...").foregroundStyle(Theme.Palette.inkTertiary),
                axis: .vertical
            )
            .font(.softNoteText)
            .foregroundStyle(Theme.Palette.ink)
            .tint(Theme.Palette.amber)
            .lineSpacing(NoteCardContent<EmptyView>.linePitch - 28.6)
            .lineLimit(NoteCardContent<EmptyView>.maxLines)
            .submitLabel(.done)
            .focused($isFocused)
            .accessibilityLabel("Note text")
            .accessibilityHint("Up to \(ComposeDraft.maxTextLength) characters. Return when done.")
            .accessibilityIdentifier("detailText")
        })
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
    }

    /// Same cap handling as the write step: accept, then clamp one tick later
    /// (clamping only in the setter leaves the field showing too much).
    private var textBinding: Binding<String> {
        Binding(
            get: { draft.text },
            set: { newValue in
                if newValue.contains(where: \.isNewline) { isFocused = false }
                let clean = ComposeDraft.sanitized(newValue)
                draft.text = newValue
                if clean != newValue {
                    DispatchQueue.main.async { draft.text = clean }
                }
            }
        )
    }

    // MARK: Flight geometry (global points)

    private var rowIconCenter: CGPoint {
        CGPoint(x: sourceFrame.minX + Theme.Metrics.rowLeading + Self.rowIconSize / 2, y: sourceFrame.midY)
    }

    /// Header icon's centre relative to the card's centre, in card coordinates.
    private var headerOffset: CGPoint {
        CGPoint(x: Card.headerIconCenter.x - Card.size.width / 2,
                y: Card.headerIconCenter.y - Card.size.height / 2)
    }

    private func rotated(_ p: CGPoint, by degrees: Double) -> CGPoint {
        let r = degrees * .pi / 180
        return CGPoint(x: p.x * cos(r) - p.y * sin(r), y: p.x * sin(r) + p.y * cos(r))
    }

    private var finalCenter: CGPoint { CGPoint(x: cardFrame.midX, y: cardFrame.midY) }

    private var finalIconCenter: CGPoint {
        let h = rotated(headerOffset, by: Self.restingRotation)
        return CGPoint(x: finalCenter.x + h.x, y: finalCenter.y + h.y)
    }

    private var closedScale: CGFloat {
        usesFlight ? Self.startScale : (isDeleting && !reduceMotion ? 0.92 : 1)
    }

    private var cardScale: CGFloat { closedScale + (1 - closedScale) * t }

    /// Card centre at t = 0 so that its (scaled, rotated) header slot is on the row's icon.
    private var cardOffset: CGSize {
        guard usesFlight, cardFrame != .zero else { return .zero }
        let h = rotated(headerOffset, by: Self.restingRotation)
        let c0 = CGPoint(x: rowIconCenter.x - Self.startScale * h.x, y: rowIconCenter.y - Self.startScale * h.y)
        return CGSize(width: (c0.x - finalCenter.x) * (1 - t), height: (c0.y - finalCenter.y) * (1 - t))
    }

    // MARK: Open / close

    private var flightAnimation: Animation { usesFlight ? Theme.Motion.smooth : Theme.Motion.crossFade }

    /// Starts the grow once the card's final frame is known (measured, not guessed).
    private func openIfNeeded(measured frame: CGRect) {
        guard !hasOpened, frame.width > 0 else { return }
        hasOpened = true
        withAnimation(flightAnimation, completionCriteria: .logicallyComplete) {
            t = 1
        } completion: {
            var instantly = Transaction()
            instantly.disablesAnimations = true
            withTransaction(instantly) {
                iconInFlight = false
                settled = true
            }
            titleFocused = true                         // VoiceOver lands on the title
        }
    }

    private func back() {
        if isPickingIcon {
            withAnimation(Theme.Motion.smooth) { isPickingIcon = false }
        } else {
            close()
        }
    }

    private func close() {
        guard settled else { return }
        var instantly = Transaction()
        instantly.disablesAnimations = true
        withTransaction(instantly) {
            settled = false
            usesFlight = flies && returnsToRow()
            iconInFlight = true                          // the one icon takes over from the card's
        }
        withAnimation(flightAnimation, completionCriteria: .logicallyComplete) {
            t = 0
        } completion: { onClose() }
    }

    private func openPicker() {
        isFocused = false
        withAnimation(Theme.Motion.smooth) { isPickingIcon = true }
    }

    // MARK: Edits

    private func commitText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }          // empty is never committed
        store.update(noteID) { $0.title = trimmed; $0.body = trimmed }
    }

    private func isBlank(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func storedText() -> String {
        guard let note = store.note(withID: noteID) else { return draft.text }
        return note.body.isEmpty ? note.title : note.body
    }

    /// Leaving the field with nothing typed discards the edit: the text from
    /// before editing began comes back (and goes back into the store — typing
    /// had committed every non-empty intermediate state).
    private func restoreTextIfEmpty() {
        guard isBlank(draft.text) else { return }
        let original = textBeforeEditing.isEmpty ? storedText() : textBeforeEditing
        draft.text = original
        commitText(original)
    }

    private func toggleSaved() {
        withAnimation(Theme.Motion.snappy) { store.toggleSaved(noteID) }
    }

    /// Confirmed: the card fades and shrinks away, then the note is deleted and
    /// the list closes the gap.
    private func deleteNote() {
        isFocused = false
        var instantly = Transaction()
        instantly.disablesAnimations = true
        withTransaction(instantly) {
            settled = false
            usesFlight = false
            iconInFlight = false
        }
        withAnimation(reduceMotion ? Theme.Motion.crossFade : Theme.Motion.snappy,
                      completionCriteria: .logicallyComplete) {
            isDeleting = true
            t = 0
        } completion: {
            withAnimation(Theme.Motion.smooth) { store.delete(noteID) }
            onClose()
        }
    }
}

// MARK: - The travelling icon

/// The row's icon becoming the card's header icon: ONE view, interpolated in
/// `t` (position, size 40 → 32, glow 1 → 0.5, rotation 0 → −3°).
private struct FlightIcon: View, Animatable {
    var icon: NoteIcon
    var t: Double
    var from: CGPoint
    var to: CGPoint
    var origin: CGPoint

    var animatableData: Double {
        get { t }
        set { t = newValue }
    }

    private func lerp(_ a: Double, _ b: Double) -> Double { a + (b - a) * t }

    var body: some View {
        StackedIconView(icon: icon, size: 40, shapeOverride: .squircle,
                        glow: lerp(1, NoteCardContent<NoteCardStaticText>.headerIconGlow))
            .scaleEffect(lerp(1, NoteCardContent<NoteCardStaticText>.headerIconSize / 40))
            .rotationEffect(.degrees(lerp(0, -3)))
            .position(x: lerp(from.x, to.x) - origin.x, y: lerp(from.y, to.y) - origin.y)
    }
}

// MARK: - Which row's icon is in flight

private struct DetailSourceNoteIDKey: EnvironmentKey {
    static let defaultValue: Note.ID? = nil
}

extension EnvironmentValues {
    /// The note whose row opened the detail overlay: its row hides its icon
    /// (the overlay's flying icon stands in for it).
    var detailSourceNoteID: Note.ID? {
        get { self[DetailSourceNoteIDKey.self] }
        set { self[DetailSourceNoteIDKey.self] = newValue }
    }
}

#Preview {
    let note = Note.samples[0]
    NoteDetailView(noteID: note.id, draft: ComposeDraft(editing: note), sourceFrame: .zero, flies: false,
                   returnsToRow: { true }, onClose: {})
        .environment(NotesStore())
        .background(Theme.Palette.canvas)
}
