import Foundation
import Observation

/// The compose flow's phases. `save` is the non-interactive fold/file-away
/// phase (built in Step 5) — it exists here so the Next button's progress arc
/// can run in thirds like the reference.
enum ComposeStep: Int, CaseIterable, Comparable {
    case pickIcon = 1, write, save

    static func < (lhs: ComposeStep, rhs: ComposeStep) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// State of one in-progress note. The container creates a fresh draft every
/// time the flow starts, so nothing leaks between compose sessions.
@Observable
final class ComposeDraft {
    /// The nav bar only counts the two steps the user interacts with
    /// ("Step 1 of 2", "Step 2 of 2" — measured from the reference), while the
    /// Next button's amber arc runs in thirds (120° → 240° → full) because the
    /// fold phase is the third.
    static let visibleStepCount = 2

    /// Tag presets the card's chip cycles through (not in the reference).
    static let tagPresets = ["Daily", "Work", "Errands", "Ideas"]

    /// Hard cap on the note text so it fits the card's 4-line text area
    /// (208pt wide, 24pt semibold). Measured by `testTextCapAndFit`: a typical
    /// 60-char sentence fits 4 lines but all-caps words ("WOW " × 15) need 5,
    /// so the cap is 48 — twelve "WOW"s fill exactly 4 lines. Only 48 unbroken
    /// wide capitals ("WWWW…") would still overflow (the field then scrolls).
    static let maxTextLength = 48

    init(createdAt: Date = .now) { self.createdAt = createdAt }

    /// An edit buffer for an existing note (Step 8's detail screen reuses the
    /// draft: icon picker, tag cycling, the text cap and the keyboard flag).
    convenience init(editing note: Note) {
        self.init(createdAt: note.createdAt)
        step = .write
        icon = note.icon
        text = note.body.isEmpty ? note.title : note.body
        tags = note.tags.isEmpty ? [Self.tagPresets[0]] : note.tags
    }

    var step: ComposeStep = .pickIcon
    var icon: NoteIcon = .defaultIcon
    var text: String = ""
    var tags: [String] = [tagPresets[0]]
    /// When the draft was started — drives the card's heading and timestamp.
    let createdAt: Date
    /// True while the write step's text field has focus (keyboard up). The
    /// flow uses it to slide the nav away and hide the status bar.
    var isEditingText = false
    /// The write step's card: its unposed layout frame in global coordinates,
    /// kept current by `WriteStep`. The fold starts from exactly here. Not
    /// observed — nothing redraws when it changes.
    @ObservationIgnored var cardFrame: CGRect = .zero

    // MARK: Derived

    /// Amber arc on the Next button: 1/3, 2/3, 3/3.
    var progress: Double { Double(step.rawValue) / Double(ComposeStep.allCases.count) }

    /// The number shown in "Step n of 2".
    var visibleStepNumber: Int { min(step.rawValue, Self.visibleStepCount) }

    /// Next is disabled on `.write` while the text is empty.
    var canAdvance: Bool {
        switch step {
        case .pickIcon: true
        case .write:    !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .save:     false
        }
    }

    var tag: String { tags.first ?? Self.tagPresets[0] }

    /// Daily → Work → Errands → Ideas → Daily.
    func cycleTag() {
        let index = Self.tagPresets.firstIndex(of: tag) ?? -1
        tags = [Self.tagPresets[(index + 1) % Self.tagPresets.count]]
    }

    /// Cleans typed input: no newlines (Return means "done"), capped length.
    static func sanitized(_ input: String) -> String {
        let cleaned = input.filter { !$0.isNewline }
        return cleaned.count > maxTextLength ? String(cleaned.prefix(maxTextLength)) : cleaned
    }

    /// The note this draft produces.
    func makeNote() -> Note {
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return Note(title: body, body: body, icon: icon, tags: tags, createdAt: .now)
    }

    // MARK: Navigation

    /// Moves to the next step. Returns false if there isn't one.
    @discardableResult
    func advance() -> Bool {
        guard canAdvance, let next = ComposeStep(rawValue: step.rawValue + 1) else { return false }
        step = next
        return true
    }

    /// Moves to the previous step. Returns false on the first step — the
    /// caller should close the flow instead.
    @discardableResult
    func goBack() -> Bool {
        guard let previous = ComposeStep(rawValue: step.rawValue - 1) else { return false }
        step = previous
        return true
    }
}
