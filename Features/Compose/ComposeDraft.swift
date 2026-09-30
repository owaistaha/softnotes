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

    var step: ComposeStep = .pickIcon
    var icon: NoteIcon = .defaultIcon
    var text: String = ""
    var tags: [String] = []

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
