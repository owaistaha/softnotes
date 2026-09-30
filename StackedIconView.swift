import SwiftUI

/// The signature icon from the reference: a saturated pastel tile tucked
/// behind a frosted-glass tile carrying a white glyph.
///
///     ┌──┐
///     │ ┌┴─┐   back: solid tone, offset up-left, rotated a few degrees
///     └─┤✿ │   front: frosted glass + tint + white hairline + glyph
///       └──┘
struct StackedIconView: View {
    let icon: NoteIcon
    var size: CGFloat = 40
    /// Rows render every icon as a squircle; folder chips use the icon's own shape.
    var shapeOverride: IconShape? = nil
    /// Inactive tab icons are shown desaturated.
    var isMuted: Bool = false

    private var shape: IconShape { shapeOverride ?? icon.shape }

    private var clip: AnyShape {
        switch shape {
        case .circle:
            AnyShape(Circle())
        case .squircle:
            AnyShape(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
        }
    }

    var body: some View {
        let tile = size * 0.84
        let shift = size * 0.09

        ZStack {
            // Back tile
            clip
                .fill(icon.tone.base.gradient)
                .frame(width: tile, height: tile)
                .rotationEffect(.degrees(-7))
                .offset(x: -shift, y: -shift)

            // Front glass tile
            ZStack {
                clip.fill(.ultraThinMaterial)
                clip.fill(
                    LinearGradient(
                        colors: [icon.tone.light.opacity(0.85), icon.tone.light.opacity(0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                clip.stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.95), .white.opacity(0.25)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: max(0.75, size / 48)
                )
                Image(systemName: icon.symbol)
                    .font(.system(size: size * 0.32, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: icon.tone.base.opacity(0.45), radius: 1.5, y: 0.5)
            }
            .frame(width: tile, height: tile)
            .offset(x: shift, y: shift)
        }
        .frame(width: size, height: size)
        .shadow(color: icon.tone.base.opacity(isMuted ? 0 : 0.30), radius: size * 0.18, y: size * 0.12)
        .saturation(isMuted ? 0 : 1)
        .opacity(isMuted ? 0.6 : 1)
        .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 24) {
        ForEach(NoteIcon.library.prefix(4)) { icon in
            StackedIconView(icon: icon, size: 56)
        }
    }
    .padding(40)
    .background(Theme.Palette.canvas)
}
