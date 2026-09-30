import SwiftUI

/// 05 Save → 06 Fold, in order. Views only *read* the phase and derive their
/// look from it; the one place that advances it is
/// `RootContainerView.save(_:)` (the timeline), using `FoldTimeline`.
enum FoldPhase: Int, Comparable {
    /// Nothing folding — the write step owns the card.
    case idle
    /// Keyboard drops, the card flies to the centre and straightens, the nav
    /// comes back, the arc completes.
    case settle
    /// The icon lifts off the card header onto the card's top edge.
    case lift
    /// Nav bar, title and Next leave (not in the original brief's list — the
    /// reference has a clear beat between the lift and the fold).
    case clear
    /// The top half folds down over the centre line.
    case fold
    /// Half-height card with the icon on its fold line. Step 5B continues
    /// from here (camera push, drop into the folder).
    case folded

    static func < (lhs: FoldPhase, rhs: FoldPhase) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// When each phase starts, in ms after the Next tap. Measured on the
/// reference at 60 fps (first visible change after the tap = 7.383 s in the
/// recording) — see the timeline table in CLAUDE.md. Our first frame lands
/// ≈40 ms after the tap, so the phases after `settle` are scheduled 40 ms
/// later than the reference's visible times to line up on video.
/// Animations for each phase live in `Theme.Motion` (`settle`, `lift`,
/// `clear`, `drop`, `fold`).
enum FoldTimeline {
    /// Keyboard starts dropping, card starts flying to the centre (ref 0–350).
    static let settle = 0
    /// Next's amber arc runs from 2/3 to full (ref ≈150–350).
    static let arcComplete = 150
    /// Icon leaves the header (ref visible 467–650).
    static let lift = 500
    /// Nav + title blur away (ref visible 934–1017); Next drops (900–1050).
    static let clear = 970
    /// Top half starts folding (ref visible 1433; edge-on ≈1567; flat, edges
    /// gone ≈1700).
    static let fold = 1470
    /// Fold lands (fold + 0.36 s).
    static let folded = 1830
    /// Step 5A only: hand the note to Home's `file(_:)` this long after the
    /// tap. (Reference: the camera push starts ≈1720; that's Step 5B.)
    static let handOff = 2050

    /// Reduce Motion: the whole sequence becomes one cross-fade (`Theme.Motion.crossFade`).
    static let reducedDuration = 0.25
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
