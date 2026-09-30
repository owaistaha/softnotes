import SwiftUI

/// 06 Fold: the paper card drawn as two halves of the *same* flat card
/// (`NoteCardContent` rendered twice, each clipped to its half), so the top
/// half can fold over the horizontal centre line.
///
///      0°             ≈60°              90°               180°
///   ┌───────┐       ┌─────────┐                           ▟▔▔▔▔▔▔▔▙  ← flap edges
///   │  top  │        \ shaded /       ━━━━━━━━━          ┌───────┐    flare out,
///   ├ ─ ─ ─ ┤ hinge  ┌───────┐        ┌───────┐          │bottom │    then vanish
///   │bottom │        │bottom │        │bottom │          └───────┘
///   └───────┘        └───────┘        └───────┘
///
/// Measured on the reference (8.82–9.07 s, 60 fps):
/// • The flap's free edge swings *toward* the viewer (it widens with
///   perspective) and darkens roughly linearly to ≈20% black at edge-on.
/// • Past 90° the flap is **behind** the bottom half: the folded result
///   shows the bottom half's own rules and tag chip, and only the flap's
///   flared edges peek out at the sides for ≈0.1 s. Here the flap's back is
///   a plain paper sheet (shading easing off as it lies flat), drawn under
///   the bottom half.
/// • The card doesn't shrink; the fold takes ≈0.25 s; result is half height.
///
/// At 0° the two halves reproduce the resting card exactly: each clip runs
/// `bleed` points past the card on its outer sides so the card's own shadow
/// is kept, and the bottom half reaches 1pt up under the top half *inside*
/// the card so a fractional-pixel fold line can't leave a hairline seam.
struct FoldingCardView: View {
    /// 0 = flat … 180 = folded (degrees).
    var angle: Double
    var content: NoteCardContent<NoteCardStaticText>

    /// Flap darkening at edge-on (reference: paper 253 → ≈204 grey).
    static let maxShade = 0.2
    /// Perspective of the flap's 3D turn.
    static let perspective: CGFloat = 0.5
    /// Room for the card's shadow around the clipped halves.
    private static let bleed: CGFloat = 60

    private var size: CGSize { NoteCardContent<NoteCardStaticText>.size }
    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
    }

    var body: some View {
        let tucked = angle > 90
        ZStack {
            if tucked { flapBack.transition(.identity) }
            content
                .clipShape(CardHalf(half: .bottom, bleed: Self.bleed, overlap: 1))
            if !tucked { flapFront.transition(.identity) }
        }
        .frame(width: size.width, height: size.height)
    }

    /// Top half, printed side: shades as it turns toward edge-on.
    private var flapFront: some View {
        content
            .overlay { shape.fill(Color.black.opacity(Self.maxShade * min(angle, 90) / 90)) }
            .clipShape(CardHalf(half: .top, bleed: Self.bleed))
            .modifier(FlapTurn(angle: angle))
    }

    /// Top half, back side: plain paper, shade easing off as it lies flat.
    private var flapBack: some View {
        shape.fill(Theme.Palette.paper)
            .overlay { shape.fill(Color.black.opacity(Self.maxShade * max(0, 180 - angle) / 90)) }
            .clipShape(CardHalf(half: .top, bleed: 0))
            .modifier(FlapTurn(angle: angle))
    }
}

/// Turns the flap about the card's horizontal centre line (the fold line),
/// free edge toward the viewer.
private struct FlapTurn: ViewModifier {
    var angle: Double

    func body(content: Content) -> some View {
        content.rotation3DEffect(
            .degrees(-angle),
            axis: (x: 1, y: 0, z: 0),
            anchor: .center,
            perspective: FoldingCardView.perspective
        )
    }
}

/// One half of the card, extended by `bleed` on its outer sides (to keep the
/// shadow). The bottom half can also reach `overlap` points up across the
/// fold line, inside the card only.
struct CardHalf: Shape {
    enum Half { case top, bottom }
    var half: Half
    var bleed: CGFloat
    var overlap: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let mid = rect.midY
        switch half {
        case .top:
            path.addRect(CGRect(x: rect.minX - bleed, y: rect.minY - bleed,
                                width: rect.width + bleed * 2, height: mid - rect.minY + bleed))
        case .bottom:
            path.addRect(CGRect(x: rect.minX - bleed, y: mid,
                                width: rect.width + bleed * 2, height: rect.maxY - mid + bleed))
            if overlap > 0 {
                path.addRect(CGRect(x: rect.minX, y: mid - overlap, width: rect.width, height: overlap))
            }
        }
        return path
    }
}

#Preview("Fold angles") {
    let content = NoteCardContent(icon: .defaultIcon, date: .now, tag: "Daily", text: "Have a good day")
    ScrollView {
        VStack(spacing: 50) {
            ForEach([0.0, 45, 80, 120, 180], id: \.self) { angle in
                FoldingCardView(angle: angle, content: content)
            }
        }
        .padding(60)
    }
    .background(Theme.Palette.canvas)
}
