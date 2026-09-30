import SwiftUI

/// The save → fold → file-away flight. Lives at the top of
/// `RootContainerView`, above both Home and compose, in full-screen global
/// space, so the card can travel from the write step into the Home folder.
///
/// It is *Animatable*: the timeline only flips `phase`, and SwiftUI
/// interpolates five progress values here, from which every frame's geometry
/// is computed in one place:
///   • settle 0 → 1  card: write-step frame + pose → screen centre, `.review` pose
///   • lift   0 → 1  icon: header slot (32pt) → centred on the top edge (82pt)
///   • fold   0 → 1  flap: 0° → 180°; the icon rides the flap's top edge down
///                   to the fold line
///   • push   0 → 1  folded card + icon rise `landing.rise` while Home rises
///   • drop   0 → 1  card slides behind the folder's front panel (shrinks,
///                   blurs, masked by the panel outline); the icon flies into
///                   the centre chip slot, shrinking and taking the chip's shape
/// The icon is ONE view the whole way (the card's own header icon is hidden
/// while the stage shows). At `landed` the container removes the stage's card
/// and adds the note in the same frame; the chip appears exactly where the
/// icon ends — no fade, no drop-in.
struct FoldStage: View, Animatable {
    var card: FoldCard?
    var landing: FoldLanding?
    private var settle: Double
    private var lift: Double
    private var fold: Double
    private var push: Double
    private var drop: Double

    init(card: FoldCard?, phase: FoldPhase, landing: FoldLanding? = nil) {
        self.card = card
        self.landing = landing
        settle = phase >= .settle ? 1 : 0
        lift = phase >= .lift ? 1 : 0
        fold = phase >= .fold ? 1 : 0
        push = phase >= .pushStep ? 1 : (phase >= .push ? Self.firstRiseFraction : 0)
        drop = phase >= .drop ? 1 : 0
    }

    var animatableData: AnimatablePair<AnimatablePair<Double, Double>, AnimatablePair<Double, AnimatablePair<Double, Double>>> {
        get { AnimatablePair(AnimatablePair(settle, lift), AnimatablePair(fold, AnimatablePair(push, drop))) }
        set {
            settle = newValue.first.first
            lift = newValue.first.second
            fold = newValue.second.first
            push = newValue.second.second.first
            drop = newValue.second.second.second
        }
    }

    /// Reference (8.0 s): the lifted icon's tiles are ≈70pt → StackedIconView
    /// size 82 (tile = 0.84 × size); its centre sits 53pt above the card's top
    /// edge, horizontally centred.
    static let landedIconSize: CGFloat = 82
    static let landedIconRise: CGFloat = 53
    /// The card shrinks to this as it slides behind the front panel (ref ≈0.86).
    static let dropScale: CGFloat = 0.86
    /// Share of the push rise done in the first step (ref: 128 of 156pt).
    static let firstRiseFraction: Double = 0.82
    /// Blur at the end of the drop (reference: the card is soft as it goes in).
    static let dropBlur: CGFloat = 8
    /// How far below the panel's body-top line the fold line ends up.
    fileprivate static let dropDepth: CGFloat = 8

    private typealias Card = NoteCardContent<NoteCardStaticText>

    var body: some View {
        GeometryReader { proxy in
            if let card {
                let origin = proxy.frame(in: .global).origin
                let geometry = FlightGeometry(card: card, landing: landing, origin: origin,
                                              size: proxy.size, settle: settle, push: push, drop: drop)
                ZStack(alignment: .topLeading) {
                    cardStack(card, geometry: geometry)
                        .mask {
                            PanelCutout(landing: landing, origin: origin, active: drop > 0)
                                .fill(style: FillStyle(eoFill: true))
                        }
                    icon(card, geometry: geometry)
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
                // Appears exactly on the write step's card; disappears in the
                // landing frame, when the chip takes over — no fades either way.
                .transition(.identity)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: Card

    private func cardStack(_ card: FoldCard, geometry: FlightGeometry) -> some View {
        FoldingCardView(
            angle: 180 * fold,
            content: Card(icon: card.icon, date: card.date, tag: card.tag, text: card.text,
                          showsHeaderIcon: false)
        )
        // Same order as NoteCardView: rotate, then scale from the bottom.
        .rotationEffect(.degrees(geometry.rotation))
        .scaleEffect(geometry.scale, anchor: .bottom)
        .blur(radius: Self.dropBlur * drop)
        .position(geometry.center)
    }

    // MARK: Icon (one view, header → top edge → fold line → chip slot)

    private func icon(_ card: FoldCard, geometry: FlightGeometry) -> some View {
        // Card-attached position/scale (what 5A drew inside the card stack).
        let angle = 180 * fold
        let size = Card.size
        let header = Card.headerIconCenter
        let landed = CGPoint(x: size.width / 2, y: -Self.landedIconRise)
        let edgeDrop = size.height / 2 * (1 - cos(min(angle, 90) * .pi / 180))
        let local = CGPoint(x: Self.lerp(header.x, landed.x, lift),
                            y: Self.lerp(header.y, landed.y, lift) + edgeDrop)
        let attached = geometry.cardToGlobal(local, dropApplied: false)
        let attachedScale = Self.lerp(Card.headerIconSize / Self.landedIconSize, 1, lift) * geometry.baseScale

        let target = landing.map { CGPoint(x: $0.chipCenter.x - geometry.origin.x,
                                           y: $0.chipCenter.y - geometry.origin.y) } ?? attached
        let targetScale = landing.map { $0.chipSize / Self.landedIconSize } ?? attachedScale
        let targetCorner = landing?.chipCornerFraction ?? StackedIconView.squircleCorner

        return StackedIconView(
            icon: card.icon,
            size: Self.landedIconSize,
            shapeOverride: .squircle,
            glow: Self.lerp(Card.headerIconGlow, 1, lift),
            cornerFraction: Self.lerp(StackedIconView.squircleCorner, targetCorner, drop)
        )
        .scaleEffect(Self.lerp(attachedScale, targetScale, drop))
        .rotationEffect(.degrees(geometry.rotation))
        .position(x: Self.lerp(attached.x, target.x, drop), y: Self.lerp(attached.y, target.y, drop))
    }

    fileprivate static func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }
}

/// The card's placement for one frame, and the card → screen mapping.
private struct FlightGeometry {
    let origin: CGPoint
    let center: CGPoint
    let rotation: Double
    /// Pose scale without the drop shrink.
    let baseScale: Double
    let scale: Double
    private let undroppedCenter: CGPoint

    private typealias Card = NoteCardContent<NoteCardStaticText>

    init(card: FoldCard, landing: FoldLanding?, origin: CGPoint, size: CGSize,
         settle: Double, push: Double, drop: Double) {
        self.origin = origin
        let lerp = FoldStage.lerp
        let half = Card.size.height / 2
        let from = CGPoint(x: card.sourceFrame.midX - origin.x, y: card.sourceFrame.midY - origin.y)
        // Whole points, so the resting card (and its fold line) sit on the pixel grid.
        let to = CGPoint(x: (size.width / 2).rounded(), y: (size.height / 2).rounded())

        rotation = lerp(card.sourcePose.rotation.degrees, NoteCardPose.review.rotation.degrees, settle)
        baseScale = lerp(card.sourcePose.scale, NoteCardPose.review.scale, settle)
        scale = baseScale * lerp(1, FoldStage.dropScale, drop)

        let pushed = CGPoint(x: lerp(from.x, to.x, settle),
                             y: lerp(from.y, to.y, settle) - (landing?.rise ?? 0) * push)
        undroppedCenter = pushed

        // Drop: the fold line (the folded card's top) ends just below the
        // panel's body-top line. With the scale anchored at the bottom edge,
        // fold line = centre.y + half − half·scale.
        var droppedY = pushed.y
        if let landing {
            let bodyTop = landing.frontPanel.minY - origin.y + FolderCard.tabHeight * landing.zoom
            let endScale = baseScale * FoldStage.dropScale
            droppedY = bodyTop + FoldStage.dropDepth - half + half * endScale
        }
        center = CGPoint(x: pushed.x, y: lerp(pushed.y, droppedY, drop))
    }

    /// Maps a point in the flat card's coordinates (origin top-left, 236×258)
    /// to the stage, through the card's rotation (about its centre) and scale
    /// (about its bottom edge).
    func cardToGlobal(_ p: CGPoint, dropApplied: Bool) -> CGPoint {
        let size = Card.size
        let c = CGPoint(x: p.x - size.width / 2, y: p.y - size.height / 2)
        let r = rotation * .pi / 180
        let v = CGPoint(x: c.x * cos(r) - c.y * sin(r), y: c.x * sin(r) + c.y * cos(r))
        let k = dropApplied ? scale : baseScale
        let bottom = size.height / 2
        let base = dropApplied ? center : undroppedCenter
        return CGPoint(x: base.x + v.x * k, y: base.y + bottom + (v.y - bottom) * k)
    }
}

/// Mask for the card during the drop: everything except the folder's front
/// panel (its `FolderShape` outline, tab included), so the card slides
/// *behind* it. A plain shape (not a Canvas — a full-screen Canvas is
/// rasterised on the CPU every frame and stalled the first frames of the
/// save by ≈0.5 s). Covers everything when inactive.
private struct PanelCutout: Shape {
    var landing: FoldLanding?
    var origin: CGPoint
    var active: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path(rect.insetBy(dx: -400, dy: -400))
        if active, let landing {
            let panel = landing.frontPanel.offsetBy(dx: -origin.x, dy: -origin.y)
            path.addPath(FolderShape(cornerRadius: Theme.Radius.folder * landing.zoom,
                                     tabHeight: FolderCard.tabHeight * landing.zoom).path(in: panel))
        }
        return path
    }
}

#Preview("Stage phases") {
    @Previewable @State var phase: FoldPhase = .settle
    let card = FoldCard(icon: .defaultIcon, date: .now, tag: "Daily", text: "Have a good day",
                        sourceFrame: CGRect(x: 83, y: 300, width: 236, height: 258),
                        sourcePose: .resting)
    let landing = FoldLanding(rise: 160, chipCenter: CGPoint(x: 210, y: 480), chipSize: 62.4,
                              chipCornerFraction: 0.28,
                              frontPanel: CGRect(x: 48, y: 560, width: 305, height: 226), zoom: 1.3)
    ZStack(alignment: .bottom) {
        Theme.Palette.canvas.ignoresSafeArea()
        FoldStage(card: card, phase: phase, landing: landing)
        Picker("Phase", selection: $phase.animation(Theme.Motion.push)) {
            Text("Settle").tag(FoldPhase.settle)
            Text("Lift").tag(FoldPhase.lift)
            Text("Fold").tag(FoldPhase.fold)
            Text("Push").tag(FoldPhase.push)
            Text("Step").tag(FoldPhase.pushStep)
            Text("Drop").tag(FoldPhase.drop)
        }
        .pickerStyle(.segmented)
        .padding()
    }
}
