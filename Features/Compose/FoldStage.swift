import SwiftUI

/// The save → fold overlay. Lives in `RootContainerView` above compose (and,
/// in Step 5B, above Home), in full-screen global space so the card can later
/// fly into the folder.
///
/// It is *Animatable*: the timeline only flips `phase`, and SwiftUI
/// interpolates three progress values here, from which every frame's geometry
/// is computed in one place:
///   • settle 0 → 1  card: write-step frame + pose → screen centre, `.review` pose
///   • lift   0 → 1  icon: header slot (32pt) → centred on the top edge (82pt)
///   • fold   0 → 1  flap: 0° → 180°; the icon rides the flap's top edge down
///                   to the fold line
/// The icon is ONE view the whole way (the card's own header icon is hidden
/// while the stage shows) — no cross-fade.
struct FoldStage: View, Animatable {
    var card: FoldCard?
    private var settle: Double
    private var lift: Double
    private var fold: Double

    init(card: FoldCard?, phase: FoldPhase) {
        self.card = card
        settle = phase >= .settle ? 1 : 0
        lift = phase >= .lift ? 1 : 0
        fold = phase >= .fold ? 1 : 0
    }

    var animatableData: AnimatablePair<Double, AnimatablePair<Double, Double>> {
        get { AnimatablePair(settle, AnimatablePair(lift, fold)) }
        set {
            settle = newValue.first
            lift = newValue.second.first
            fold = newValue.second.second
        }
    }

    /// Reference (8.0 s): the lifted icon's tiles are ≈70pt → StackedIconView
    /// size 82 (tile = 0.84 × size); its centre sits 53pt above the card's top
    /// edge, horizontally centred.
    static let landedIconSize: CGFloat = 82
    static let landedIconRise: CGFloat = 53

    private typealias Card = NoteCardContent<NoteCardStaticText>

    var body: some View {
        GeometryReader { proxy in
            if let card {
                let origin = proxy.frame(in: .global).origin
                let from = CGPoint(x: card.sourceFrame.midX - origin.x,
                                   y: card.sourceFrame.midY - origin.y)
                // Whole points, so the resting card (and its fold line) sit on
                // the pixel grid.
                let to = CGPoint(x: (proxy.size.width / 2).rounded(),
                                 y: (proxy.size.height / 2).rounded())

                stack(card)
                    // Same order as NoteCardView: rotate, then scale from the bottom.
                    .rotationEffect(.degrees(Self.lerp(card.sourcePose.rotation.degrees,
                                                       NoteCardPose.review.rotation.degrees, settle)))
                    .scaleEffect(Self.lerp(card.sourcePose.scale, NoteCardPose.review.scale, settle),
                                 anchor: .bottom)
                    .position(x: Self.lerp(from.x, to.x, settle), y: Self.lerp(from.y, to.y, settle))
                    // Appears exactly where the write step's card was (which
                    // hides in the same frame); fades on the hand-off.
                    .transition(.asymmetric(insertion: .identity, removal: .opacity))
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func stack(_ card: FoldCard) -> some View {
        let angle = 180 * fold
        return FoldingCardView(
            angle: angle,
            content: Card(icon: card.icon, date: card.date, tag: card.tag, text: card.text,
                          showsHeaderIcon: false)
        )
        .overlay(alignment: .topLeading) {
            StackedIconView(
                icon: card.icon,
                size: Self.landedIconSize,
                shapeOverride: .squircle,
                glow: Self.lerp(Card.headerIconGlow, 1, lift)
            )
            .scaleEffect(Self.lerp(Card.headerIconSize / Self.landedIconSize, 1, lift))
            .position(iconCenter(angle: angle))
        }
    }

    /// Header slot → top-edge centre, then down with the flap's top edge
    /// (orthographic h/2·(1 − cos θ)) until the flap is edge-on; after that
    /// the fold line *is* the top edge.
    private func iconCenter(angle: Double) -> CGPoint {
        let size = Card.size
        let header = Card.headerIconCenter
        let landed = CGPoint(x: size.width / 2, y: -Self.landedIconRise)
        let edgeDrop = size.height / 2 * (1 - cos(min(angle, 90) * .pi / 180))
        return CGPoint(x: Self.lerp(header.x, landed.x, lift),
                       y: Self.lerp(header.y, landed.y, lift) + edgeDrop)
    }

    private static func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }
}

#Preview("Stage phases") {
    @Previewable @State var phase: FoldPhase = .settle
    let card = FoldCard(icon: .defaultIcon, date: .now, tag: "Daily", text: "Have a good day",
                        sourceFrame: CGRect(x: 83, y: 300, width: 236, height: 258),
                        sourcePose: .resting)
    ZStack(alignment: .bottom) {
        Theme.Palette.canvas.ignoresSafeArea()
        FoldStage(card: card, phase: phase)
        Picker("Phase", selection: $phase.animation(Theme.Motion.fold)) {
            Text("Settle").tag(FoldPhase.settle)
            Text("Lift").tag(FoldPhase.lift)
            Text("Fold").tag(FoldPhase.fold)
        }
        .pickerStyle(.segmented)
        .padding()
    }
}
