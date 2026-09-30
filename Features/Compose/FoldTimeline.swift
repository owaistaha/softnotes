import SwiftUI

/// 05 Save → 06 Fold → 07 File it away, in order. Views only *read* the
/// phase and derive their look from it; the one place that advances it is
/// `RootContainerView.save(_:)` (the timeline), using `FoldTimeline`.
enum FoldPhase: Int, Comparable {
    /// Nothing folding — the write step owns the card.
    case idle
    /// Keyboard drops, the card flies to the centre and straightens, the nav
    /// comes back, the arc completes.
    case settle
    /// The icon lifts off the card header onto the card's top edge.
    case lift
    /// Nav bar, title and Next leave.
    case clear
    /// The top half folds down over the centre line.
    case fold
    /// Half-height card with the icon on its fold line. Behind it (invisible
    /// still) compose closes and Home is set up: zoomed ×1.3 on the folder,
    /// folder open, below the screen, header/Recent/tab bar hidden.
    case folded
    /// Home rises into view (zoomed) while the folded card rises above it.
    case push
    /// The card drops behind the front panel (blur ramp); the icon flies into
    /// the centre chip slot.
    case drop
    /// The icon *becomes* the centre chip: the note is added (count rolls,
    /// chips shuffle, folder bounces). Recent still holds the new row back.
    case landed
    /// The toggle flips on — the folder closes.
    case close
    /// Home zooms back to ×1; header, Recent and tab bar return.
    case zoomOut
    /// The new row blur-slides into the top of Recent.
    case rowEntry

    static func < (lhs: FoldPhase, rhs: FoldPhase) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// When each phase starts, in ms after the Next tap. Measured on the
/// reference at 60 fps (first visible change after the tap = 7.383 s in the
/// recording) — see the timeline table in CLAUDE.md. Our first frame lands
/// ≈40 ms after the tap, so the phases after `settle` are scheduled 40 ms
/// later than the reference's visible times to line up on video.
/// Animations for each phase live in `Theme.Motion` (`settle`, `lift`,
/// `clear`, `drop`, `fold`, `push`, `dropIn`, `zoomOut`, `chromeIn`).
enum FoldTimeline {
    /// Keyboard starts dropping, card starts flying to the centre (ref 0–350).
    static let settle = 0
    /// Next's amber arc runs from 2/3 to full (ref ≈150–350).
    static let arcComplete = 150
    /// Icon leaves the header (ref visible 467–650; the lift spring moves
    /// visibly in its first frame, so this is scheduled later than that).
    static let lift = 600
    /// Nav + title blur away (ref visible 934–1017); Next drops (900–1050).
    static let clear = 970
    /// Top half starts folding (ref visible 1433; edge-on ≈1567; flat, edges
    /// gone ≈1700).
    static let fold = 1470
    /// Fold lands (fold + 0.36 s); Home is prepared out of sight.
    static let folded = 1830
    /// Home rises from below, zoomed ×1.3; the folded card rises ≈160pt
    /// (ref: card 1967→≈2670, folder 2017→≈2470).
    static let push = 2000
    /// Card drops behind the front panel, icon flies to the chip slot
    /// (ref 2950→≈3190). The landing (note added) fires when this animation
    /// completes — the icon is then exactly on the slot — at ≈3280, so the
    /// icon arrives ≈3170–3220 visibly, like the reference (whose count roll
    /// runs ≈3040–3140, slightly before its icon settles).
    static let drop = 3040
    /// Toggle flips on / folder closes this long after the landing (ref: icon
    /// lands ≈3170–3220, toggle reads lavender from ≈3500). Relative, because
    /// the landing waits for the drop animation to finish. The track's colour
    /// takes ≈170 ms to read as lavender on video, hence the short gap.
    static let closeAfterLanding = 130
    /// Zoom back to ×1, header/Recent/tab bar fade in (ref 3950→≈4520).
    static let zoomOut = 3990
    /// New row blur-slides into Recent (ref 4970→≈5370; scheduled earlier
    /// because the blur-slide only reads as "in" a few frames after it starts).
    static let rowEntry = 4920
    /// Sequence over; overlay state cleared.
    static let done = 5450

    /// Reduce Motion: the whole sequence becomes one cross-fade (`Theme.Motion.crossFade`).
    static let reducedDuration = 0.25
}

/// Where the flight lands, in global coordinates (Home zoomed and risen).
/// Computed by the container from the folder's frame (`FolderCard`'s static
/// geometry) — not guessed.
struct FoldLanding: Equatable {
    /// How far the folded card rises during the push (pt).
    var rise: CGFloat
    /// Centre of the centre chip slot at the moment the chip appears.
    var chipCenter: CGPoint
    /// Rendered chip size there (48 × zoom).
    var chipSize: CGFloat
    /// Corner fraction of the chip's shape (circle ≈ 0.5, squircle 0.28).
    var chipCornerFraction: CGFloat
    /// The front panel's frame (zoomed); the card slides behind its outline.
    var frontPanel: CGRect
    /// Home's zoom, for the panel outline's tab and corner radius.
    var zoom: CGFloat
}

/// Everything the fold needs to draw the card, captured at the Next tap so it
/// doesn't depend on the draft (or the write step) afterwards.
struct FoldCard: Equatable {
    var icon: NoteIcon
    var date: Date
    var tag: String
    var text: String
    /// The write step's card: unposed layout frame in global coordinates, and
    /// the pose it was drawn with — the fold starts exactly there.
    var sourceFrame: CGRect
    var sourcePose: NoteCardPose
}

extension FoldCard {
    init(note: Note, date: Date, sourceFrame: CGRect, sourcePose: NoteCardPose) {
        self.init(
            icon: note.icon,
            date: date,
            tag: note.tags.first ?? ComposeDraft.tagPresets[0],
            text: note.body,
            sourceFrame: sourceFrame,
            sourcePose: sourcePose
        )
    }
}
