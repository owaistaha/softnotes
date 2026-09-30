import SwiftUI

/// 03_Pick_an_icon
///
///        Select an icon
///        for your note
///
///           ╭───────╮
///           │  ◈    │     ← preview of the selected icon (springs on change)
///           ╰───────╯
///        (◈) (◈) (◈) (◈)
///        (◈) (◈) (◈) (◈)   ← 4×3 grid of `NoteIcon.library`; a thin ring in the
///        (◈) (◈) (◈) (◈)     tone's colour marks the selection and glides
///                            between cells (matchedGeometryEffect)
///
/// The nav bar and Next button live in `ComposeFlowView`, not here.
struct IconPickerStep: View {
    @Bindable var draft: ComposeDraft
    @Namespace private var ringNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let columns = 4

    var body: some View {
        VStack(spacing: 0) {
            // Two stacked lines with a negative gap: SwiftUI ignores negative
            // `lineSpacing`, and the reference's leading is tight (31pt pitch at 28pt).
            VStack(spacing: -2.5) {
                Text("Select an icon")
                Text("for your note")
            }
            .font(.softTitle)
            .tracking(-0.4)
            .foregroundStyle(Theme.Palette.ink)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            .padding(.top, Theme.Metrics.pickerTitleTop)

            preview
                .padding(.top, Theme.Metrics.pickerPreviewTop)

            grid
                .padding(.top, Theme.Metrics.pickerGridTop)
        }
        .frame(maxWidth: .infinity)
        // Light haptic whenever the selection changes (not on first appear).
        .sensoryFeedback(.impact(weight: .light), trigger: draft.icon)
    }

    // MARK: Preview

    private var preview: some View {
        ZStack {
            StackedIconView(icon: draft.icon, size: 72, shapeOverride: .squircle, glass: .vivid)
                // New identity per icon → the old one shrinks out, the new one springs in.
                .id(draft.icon.id)
                .transition(reduceMotion ? .opacity : .scale(scale: 0.6).combined(with: .opacity))
        }
        .frame(width: Theme.Metrics.pickerPreview, height: Theme.Metrics.pickerPreview)
        // Keep the icon's tone glow inside the white disc (the reference has no halo outside).
        .clipShape(Circle())
        .background(SoftSurface(Circle(), elevation: .raised))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Selected icon: \(draft.icon.accessibilityName)")
        .accessibilityIdentifier("iconPreview")
    }

    // MARK: Grid

    private var grid: some View {
        let icons = NoteIcon.library
        let rows = stride(from: 0, to: icons.count, by: columns).map { Array(icons[$0..<min($0 + columns, icons.count)]) }

        let grid = Grid(horizontalSpacing: Theme.Metrics.pickerSpacing, verticalSpacing: Theme.Metrics.pickerSpacing) {
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                GridRow {
                    ForEach(Array(row.enumerated()), id: \.element.id) { column, icon in
                        IconCell(
                            icon: icon,
                            isSelected: icon == draft.icon,
                            // Reduce Motion: each cell fades its own ring in/out
                            // instead of one ring gliding between cells.
                            showsOwnRing: reduceMotion && icon == draft.icon,
                            ringNamespace: ringNamespace
                        ) {
                            withAnimation(reduceMotion ? Theme.Motion.crossFade : Theme.Motion.bouncy) {
                                draft.icon = icon
                            }
                        }
                        .accessibilityIdentifier("iconCell_\(rowIndex * columns + column)")
                    }
                }
            }
        }

        return grid.overlay { if !reduceMotion { selectionRing } }
    }

    /// One persistent ring that follows the selected cell. Each cell publishes
    /// itself as a (non-moving) matched-geometry source; the ring is a
    /// non-source view whose *position* is matched to the selected cell, so
    /// changing the selection glides it there (in the surrounding
    /// `withAnimation`). Position only: the ring keeps its own 80pt size, and
    /// its colour interpolates between the two tones.
    private var selectionRing: some View {
        Circle()
            .strokeBorder(draft.icon.tone.ring, lineWidth: Theme.Metrics.pickerRingWidth)
            .frame(width: Theme.Metrics.pickerRing, height: Theme.Metrics.pickerRing)
            .matchedGeometryEffect(id: draft.icon.id, in: ringNamespace,
                                   properties: .position, anchor: .center, isSource: false)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

// MARK: - Cell

private struct IconCell: View {
    let icon: NoteIcon
    let isSelected: Bool
    var showsOwnRing: Bool = false
    let ringNamespace: Namespace.ID
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            // Squircle tiles in every cell (the reference doesn't use the
            // circle variants here), on a white circular surface.
            StackedIconView(icon: icon, size: 40, shapeOverride: .squircle, glow: 0.5, glass: .vivid)
                .frame(width: Theme.Metrics.pickerCell, height: Theme.Metrics.pickerCell)
                .clipShape(Circle())   // glow stays inside the white cell
                .background(SoftSurface(Circle(), elevation: .raised))
        }
        .buttonStyle(IconCellButtonStyle(tone: icon.tone))
        .overlay {
            if showsOwnRing {
                Circle()
                    .strokeBorder(icon.tone.ring, lineWidth: Theme.Metrics.pickerRingWidth)
                    .frame(width: Theme.Metrics.pickerRing, height: Theme.Metrics.pickerRing)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        // Anchor for the shared selection ring (see IconPickerStep.selectionRing).
        .background {
            Color.clear
                .frame(width: Theme.Metrics.pickerCell, height: Theme.Metrics.pickerCell)
                .matchedGeometryEffect(id: icon.id, in: ringNamespace, isSource: true)
        }
        .accessibilityLabel(icon.accessibilityName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Pressed state (from the reference): the cell dips slightly, tints, and
/// shows a ring in its own tone that fades away on release.
private struct IconCellButtonStyle: ButtonStyle {
    let tone: PastelTone

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay {
                Circle()
                    .fill(tone.base.opacity(configuration.isPressed ? 0.16 : 0))
                    .allowsHitTesting(false)
            }
            .overlay {
                Circle()
                    .strokeBorder(tone.ring, lineWidth: Theme.Metrics.pickerRingWidth)
                    .frame(width: Theme.Metrics.pickerRing, height: Theme.Metrics.pickerRing)
                    .opacity(configuration.isPressed ? 1 : 0)
                    .allowsHitTesting(false)
            }
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(duration: 0.25, bounce: 0.3), value: configuration.isPressed)
    }
}

#Preview {
    @Previewable @State var draft = ComposeDraft()
    IconPickerStep(draft: draft)
        .padding(20)
        .background(Theme.Palette.canvas)
}
