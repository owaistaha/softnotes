import SwiftUI

/// The hero of Home: a soft 3D folder with the latest note icons peeking out.
///
///            (◉)        ◉          ← chips: newest centre, then left, then right
///      (◉)        [◉]              idle-float; parallax with tilt
///     ╭─────────╮______________
///     │  back panel + paper     │  ← back panel
///   ╭─────────╮╲_______________╮
///   │         ╰────────────────│  ← front panel (FolderShape), hinges on its
///   │                          │     bottom edge when the folder "opens"
///   │  (9)        [ Notes ◯ ]  │  ← count bubble + toggle
///   ╰──────────────────────────╯
///
/// Interactions
/// • Drag anywhere on it → the whole folder tilts in 3D and springs back.
/// • Toggle → open (front panel leans forward, chips lift) / closed.
/// • `count` changes → numeric roll + a small "received" bounce.
struct FolderCard: View {
    let count: Int
    let previews: [Note]
    @Binding var isOpen: Bool
    /// The note whose icon is being handed over by the save flight: its chip
    /// appears in place with no drop-in transition (the flying icon *is* it
    /// until that frame).
    var landingNoteID: Note.ID? = nil
    /// The save flight is coming: the chips move one slot along (centre →
    /// left, left → right, right leaves) so the centre slot is EMPTY when the
    /// icon arrives (reference: only two chips during the push). When the
    /// note is added this turns off in the same transaction — every old chip
    /// is then already in its new slot, so nothing crosses the landing chip.
    var vacatesCentre: Bool = false
    /// What the "received" bounce follows (default: `count`). The save shows
    /// the count one ahead while the icon is still flying; the bounce waits
    /// for the note itself, because the landing point is computed for the
    /// folder at rest — bouncing earlier would move the chip off the icon.
    var receivedCount: Int? = nil
    /// Home scrolls (short screens, e.g. iPhone SE with three Recent rows).
    /// The tilt's drag then starts only after 20pt, past the scroll view's
    /// own pan threshold — at 4pt it won every drag and Home could not be
    /// scrolled from the folder at all (6B, measured with a UI test) — and a
    /// drag that starts vertical is left to the scroll view (no tilt), so
    /// the two never fight. Where Home fits, the tilt is unchanged.
    var sharesDragsWithScroll: Bool = false
    var onTap: () -> Void = {}

    @State private var tilt: CGSize = .zero
    /// Decided on a drag's first movement (scrolling Home only): true =
    /// vertical, the scroll view's — no tilt for this drag.
    @State private var dragIsScroll: Bool?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Geometry measured from the reference (points, 393pt-wide phone).
    // Static so the save flight can aim at it from the folder's frame alone.
    static let size = CGSize(width: 235, height: 276)
    static let frontHeight: CGFloat = 174      // incl. 25pt tab
    static let tabHeight: CGFloat = 25
    /// How far the back panel peeks above the front panel's body.
    static let backPeek: CGFloat = 43
    static var frontTop: CGFloat { size.height - frontHeight }     // 102
    static var bodyTop: CGFloat { frontTop + tabHeight }           // 127
    static let chipSize: CGFloat = 48
    /// Chips lift this much while the folder is open.
    static let openLift: CGFloat = 14
    static let chipFloat: CGFloat = 2.5

    private var width: CGFloat { Self.size.width }
    private var height: CGFloat { Self.size.height }
    private var frontHeight: CGFloat { Self.frontHeight }
    private var tabHeight: CGFloat { Self.tabHeight }
    private var backPeek: CGFloat { Self.backPeek }
    private var frontTop: CGFloat { Self.frontTop }
    private var bodyTop: CGFloat { Self.bodyTop }

    var body: some View {
        ZStack(alignment: .topLeading) {
            backPanel
                .frame(width: width - 14, height: 184)
                .position(x: width / 2, y: bodyTop - backPeek + 92)

            chips

            frontPanel
                .frame(width: width, height: frontHeight)
                .position(x: width / 2, y: frontTop + frontHeight / 2)
        }
        .frame(width: width, height: height)
        // 3D tilt from drag
        .rotation3DEffect(.degrees(tilt.width), axis: (x: 0, y: 1, z: 0), perspective: 0.55)
        .rotation3DEffect(.degrees(-tilt.height), axis: (x: 1, y: 0, z: 0), perspective: 0.55)
        // "Received a note" bounce whenever the count changes
        // (Off with Reduce Motion: the trigger never changes.)
        .keyframeAnimator(initialValue: 1.0, trigger: reduceMotion ? 0 : (receivedCount ?? count)) { content, scale in
            content.scaleEffect(scale, anchor: .bottom)
        } keyframes: { _ in
            SpringKeyframe(0.96, duration: 0.12, spring: .snappy)
            SpringKeyframe(1.03, duration: 0.22, spring: .bouncy)
            SpringKeyframe(1.0, duration: 0.35, spring: .smooth)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .simultaneousGesture(tiltGesture)
        .sensoryFeedback(.impact(weight: .light), trigger: isOpen)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Notes folder, \(count) \(count == 1 ? "note" : "notes")")
        .accessibilityValue(isOpen ? "Open" : "Closed")
        .accessibilityIdentifier("folder")
    }

    // MARK: Back panel

    private var backPanel: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.folder, style: .continuous)
        return ZStack(alignment: .top) {
            SoftSurface(
                shape,
                fill: LinearGradient(
                    colors: [Color(hex: 0xFBFBFB), Color(hex: 0xEDEDEE)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                elevation: .raised
            )
            // Paper sheet edge peeking out
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.6))
                )
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .offset(y: isOpen ? -8 : 0)
        }
    }

    // MARK: Chips

    private var chips: some View {
        ZStack(alignment: .topLeading) {
            ForEach(chipSlots, id: \.note.id) { note, index in
                let slot = Self.chipSlot(index)
                StackedIconView(icon: note.icon, size: Self.chipSize)
                    .rotationEffect(.degrees(slot.rotation))
                    .idleFloat(amplitude: Self.chipFloat, period: 2.4 + Double(index) * 0.45)
                    // Chips are "closer" to the viewer than the folder → parallax
                    .offset(x: tilt.width * 0.9, y: -tilt.height * 0.9)
                    .position(
                        x: slot.point.x,
                        y: slot.point.y + (isOpen ? -14 : 0)
                    )
                    .transition(note.id == landingNoteID ? .identity
                                : reduceMotion ? .opacity : Self.chipTransition)
                    // Newest on top: the chip that just landed must never pass
                    // behind the old centre chip shuffling out (video: it hid
                    // the hand-off for 3 frames).
                    .zIndex(Double(Self.slotCount - index))
            }
        }
        .frame(width: width, height: height)
        .animation(Theme.Motion.bouncy, value: previews.map(\.id))
        .animation(Theme.Motion.bouncy, value: vacatesCentre)
        .animation(Theme.Motion.bouncy, value: isOpen)
    }

    static let slotCount = 3

    /// Which note sits in which slot (0 centre, 1 left, 2 right).
    private var chipSlots: [(note: Note, index: Int)] {
        let shift = vacatesCentre ? 1 : 0
        return previews.prefix(Self.slotCount - shift).enumerated().map { ($1, $0 + shift) }
    }

    private static var chipTransition: AnyTransition {
        .asymmetric(
            insertion: .offset(y: -60).combined(with: .scale(scale: 0.4)).combined(with: .opacity),
            removal: .offset(y: 50).combined(with: .opacity)
        )
    }

    /// Chip slot in the folder's own coordinates (closed, before idle float).
    static func chipSlot(_ index: Int) -> (point: CGPoint, rotation: Double) {
        switch index {
        // Centre (newest) sits lowest, overlapping the back panel's top edge.
        case 0:  (CGPoint(x: size.width / 2 + 9,  y: bodyTop - 58), 0)
        case 1:  (CGPoint(x: size.width / 2 - 71, y: bodyTop - 62), -8)    // left
        default: (CGPoint(x: size.width / 2 + 64, y: bodyTop - 95), 6)     // right, highest
        }
    }

    /// Where a chip is drawn for a folder laid out at `folderFrame` (any
    /// coordinate space, unscaled): slot + open lift. `floatStart` adds where
    /// a freshly inserted chip's idle float begins (its first phase is down).
    static func chipCenter(_ index: Int, in folderFrame: CGRect, isOpen: Bool,
                           floatStart: Bool = false) -> CGPoint {
        let slot = chipSlot(index).point
        return CGPoint(x: folderFrame.minX + slot.x,
                       y: folderFrame.minY + slot.y - (isOpen ? openLift : 0) + (floatStart ? chipFloat : 0))
    }

    /// The front panel's frame (its outline is `FolderShape`, tab included).
    static func frontPanelFrame(in folderFrame: CGRect) -> CGRect {
        CGRect(x: folderFrame.minX, y: folderFrame.minY + frontTop,
               width: size.width, height: frontHeight)
    }

    // MARK: Front panel

    private var frontPanel: some View {
        let shape = FolderShape(cornerRadius: Theme.Radius.folder, tabHeight: tabHeight)

        return ZStack(alignment: .bottom) {
            SoftSurface(
                shape,
                fill: LinearGradient(gradient: Theme.Palette.folderFront,
                                     startPoint: .top, endPoint: .bottom),
                elevation: .folder
            )

            HStack {
                countBubble
                Spacer()
                FolderToggle(title: "Notes", isOn: Binding(
                    get: { !isOpen },
                    set: { isOpen = !$0 }
                ))
                .accessibilityIdentifier("folderToggle")
            }
            .padding(15)
        }
        // Opening = front panel hinges forward on its bottom edge. Kept small:
        // in the reference the panel stays nearly flat when open.
        .rotation3DEffect(
            .degrees(isOpen ? -6 : 0),
            axis: (x: 1, y: 0, z: 0),
            anchor: .bottom,
            perspective: 0.45
        )
        .animation(Theme.Motion.bouncy, value: isOpen)
    }

    private var countBubble: some View {
        Text(count, format: .number)
            .font(.system(size: 19, weight: .regular))
            .foregroundStyle(Theme.Palette.inkSecondary)
            .contentTransition(.numericText(value: Double(count)))
            .animation(Theme.Motion.snappy, value: count)
            .frame(width: Theme.Metrics.countBubble, height: Theme.Metrics.countBubble)
            .background(SoftSurface(Circle(), elevation: .raised))
            .overlay(Circle().strokeBorder(Theme.Palette.hairline, lineWidth: 1))
            .accessibilityHidden(true)
    }

    // MARK: Tilt gesture

    private var tiltGesture: some Gesture {
        DragGesture(minimumDistance: sharesDragsWithScroll ? 20 : 4)
            .onChanged { value in
                if sharesDragsWithScroll {
                    let t = value.translation
                    if dragIsScroll == nil { dragIsScroll = abs(t.height) > abs(t.width) }
                    if dragIsScroll == true { return }
                }
                applyTilt(value.translation)
            }
            .onEnded { _ in
                dragIsScroll = nil
                releaseTilt()
            }
    }

    private func applyTilt(_ translation: CGSize) {
        withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.7)) {
            tilt = CGSize(
                width: (translation.width / 10).clamped(to: -14...14),
                height: (translation.height / 12).clamped(to: -10...10)
            )
        }
    }

    private func releaseTilt() {
        withAnimation(Theme.Motion.release) { tilt = .zero }
    }
}

// MARK: - Folder shape (front panel with tab)

struct FolderShape: Shape {
    var cornerRadius: CGFloat = 24
    var tabHeight: CGFloat = 25
    /// Where the tab's flat top ends (measured: 0.38 of the width; the
    /// S-curve then runs to ≈0.50, per reference).
    var tabWidthRatio: CGFloat = 0.38
    /// Horizontal run of the S-curve from the tab down to the body.
    var tabSlope: CGFloat = 27

    func path(in rect: CGRect) -> Path {
        let r = cornerRadius
        let tabR = min(r, 18)
        let bodyTop = rect.minY + tabHeight
        let tabEnd = rect.minX + rect.width * tabWidthRatio

        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY - r))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tabR))
        p.addQuadCurve(to: CGPoint(x: rect.minX + tabR, y: rect.minY),
                       control: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: tabEnd, y: rect.minY))
        p.addCurve(to: CGPoint(x: tabEnd + tabSlope, y: bodyTop),
                   control1: CGPoint(x: tabEnd + tabSlope * 0.5, y: rect.minY),
                   control2: CGPoint(x: tabEnd + tabSlope * 0.5, y: bodyTop))
        p.addLine(to: CGPoint(x: rect.maxX - r, y: bodyTop))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: bodyTop + r),
                       control: CGPoint(x: rect.maxX, y: bodyTop))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY),
                       control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r),
                       control: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - "Notes" toggle

/// Off: grey track, knob left, label right.  On: lavender, knob right, label left.
struct FolderToggle: View {
    let title: String
    @Binding var isOn: Bool

    private let size = CGSize(width: 116, height: 46)
    private let knob: CGFloat = 40
    private var knobInset: CGFloat { (size.height - knob) / 2 }
    /// Label keeps clear of the knob on the knob's side.
    private var knobSide: CGFloat { knob + knobInset + 3 }
    /// Label inset on the side away from the knob (ref: ink 15.9pt in).
    private let labelInset: CGFloat = 15

    var body: some View {
        Button {
            withAnimation(Theme.Motion.snappy) { isOn.toggle() }
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(
                        (isOn ? Theme.Palette.lavenderTint : Theme.Palette.track)
                            .shadow(.inner(color: .black.opacity(0.06), radius: 2, y: 1))
                    )
                    .overlay {
                        Capsule()
                            .strokeBorder(Theme.Palette.toggleRim, lineWidth: 2)
                            .blur(radius: 0.8)
                            .clipShape(Capsule())
                    }

                Text(title)
                    .font(.softToggleLabel)
                    .lineLimit(1)
                    .foregroundStyle(isOn ? Theme.Palette.lavenderInk : Theme.Palette.inkSecondary)
                    .frame(maxWidth: .infinity, alignment: isOn ? .leading : .trailing)
                    .padding(.leading, isOn ? labelInset : knobSide)
                    .padding(.trailing, isOn ? knobSide : labelInset)

                Circle()
                    .fill(.white)
                    .shadow(color: .black.opacity(0.10), radius: 4, y: 2)
                    .frame(width: knob, height: knob)
                    .padding(knobInset)
            }
            .frame(width: size.width, height: size.height)
        }
        .buttonStyle(.pressable)
        .sensoryFeedback(.selection, trigger: isOn)
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(.isToggle)
    }
}

#Preview {
    @Previewable @State var open = false
    @Previewable @State var store = NotesStore()
    VStack(spacing: 40) {
        FolderCard(count: store.count, previews: store.folderPreview, isOpen: $open)
        Button("Add note") {
            withAnimation(Theme.Motion.bouncy) { store.add(.demo()) }
        }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.Palette.canvas)
}
