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
    var onTap: () -> Void = {}

    @State private var tilt: CGSize = .zero

    // Geometry measured from the reference (points, 393pt-wide phone).
    private let width: CGFloat = 235
    private let height: CGFloat = 276
    private let frontHeight: CGFloat = 174      // incl. 25pt tab
    private let tabHeight: CGFloat = 25
    /// How far the back panel peeks above the front panel's body.
    private let backPeek: CGFloat = 43
    private var frontTop: CGFloat { height - frontHeight }        // 102
    private var bodyTop: CGFloat { frontTop + tabHeight }          // 127

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
        .keyframeAnimator(initialValue: 1.0, trigger: count) { content, scale in
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
        .accessibilityLabel("Notes folder, \(count) notes")
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
            ForEach(Array(previews.enumerated()), id: \.element.id) { index, note in
                let slot = chipSlot(index)
                StackedIconView(icon: note.icon, size: 48)
                    .rotationEffect(.degrees(slot.rotation))
                    .idleFloat(amplitude: 2.5, period: 2.4 + Double(index) * 0.45)
                    // Chips are "closer" to the viewer than the folder → parallax
                    .offset(x: tilt.width * 0.9, y: -tilt.height * 0.9)
                    .position(
                        x: slot.point.x,
                        y: slot.point.y + (isOpen ? -14 : 0)
                    )
                    .transition(
                        .asymmetric(
                            insertion: .offset(y: -60).combined(with: .scale(scale: 0.4)).combined(with: .opacity),
                            removal: .offset(y: 50).combined(with: .opacity)
                        )
                    )
            }
        }
        .frame(width: width, height: height)
        .animation(Theme.Motion.bouncy, value: previews.map(\.id))
        .animation(Theme.Motion.bouncy, value: isOpen)
    }

    private func chipSlot(_ index: Int) -> (point: CGPoint, rotation: Double) {
        switch index {
        // Centre (newest) sits lowest, overlapping the back panel's top edge.
        case 0:  (CGPoint(x: width / 2 + 9,  y: bodyTop - 58), 0)
        case 1:  (CGPoint(x: width / 2 - 71, y: bodyTop - 62), -8)    // left
        default: (CGPoint(x: width / 2 + 64, y: bodyTop - 95), 6)     // right, highest
        }
    }

    // MARK: Front panel

    private var frontPanel: some View {
        let shape = FolderShape(cornerRadius: Theme.Radius.folder, tabHeight: tabHeight)

        return ZStack(alignment: .bottom) {
            SoftSurface(
                shape,
                fill: LinearGradient(
                    colors: [.white, Color(hex: 0xF5F5F6)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                elevation: .folder
            )

            HStack {
                countBubble
                Spacer()
                FolderToggle(title: "Notes", isOn: Binding(
                    get: { !isOpen },
                    set: { isOpen = !$0 }
                ))
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
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.7)) {
                    tilt = CGSize(
                        width: (value.translation.width / 10).clamped(to: -14...14),
                        height: (value.translation.height / 12).clamped(to: -10...10)
                    )
                }
            }
            .onEnded { _ in
                withAnimation(Theme.Motion.release) { tilt = .zero }
            }
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
    private var knobSide: CGFloat { knob + knobInset + 6 }

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

                Text(title)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(isOn ? Theme.Palette.lavenderInk : Theme.Palette.inkSecondary)
                    .frame(maxWidth: .infinity, alignment: isOn ? .leading : .trailing)
                    .padding(.leading, isOn ? 16 : knobSide)
                    .padding(.trailing, isOn ? knobSide : 16)

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
