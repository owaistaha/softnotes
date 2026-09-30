import SwiftUI

/// How the paper card is posed. The *content* never changes with the pose —
/// only rotation / scale / shadow do — so Step 5 can render `NoteCardContent`
/// twice and mask it into halves for the fold.
enum NoteCardPose {
    /// Write step, keyboard down: tilted −3° (reference measures −2.7°).
    case resting
    /// Write step, keyboard up: grown ×1.2 and nearly straight (−1.5°).
    case editing
    /// Save step: centred, straight, and a touch larger (reference: the
    /// settled save card measures ≈2.5% bigger than the resting write card).
    case review

    var rotation: Angle {
        switch self {
        case .resting: .degrees(-3)
        case .editing: .degrees(-1.5)
        case .review:  .zero
        }
    }

    var scale: CGFloat {
        switch self {
        case .resting: 1
        case .editing: 1.2
        case .review:  1.025
        }
    }
}

/// The paper card ("chit"), posed. Scale is anchored at the bottom so the card
/// grows *upward* when editing and its bottom edge stays where layout put it
/// (just above the Next button).
struct NoteCardView<TextArea: View>: View {
    var pose: NoteCardPose
    var content: NoteCardContent<TextArea>

    var body: some View {
        content
            .rotationEffect(pose.rotation)
            .scaleEffect(pose.scale, anchor: .bottom)
    }
}

/// The flat, unrotated card: paper, header, ruled lines, text area, tag chip.
/// One view, fixed size — safe to duplicate and mask.
///
///     ┌──────────────────────────────┐
///     │ ◈  Morning note              │  ← picked icon, time-of-day heading
///     │    28 Sep · 9:41             │
///     │ - - - - - - - - - - - - - - -│  ← dashed divider
///     │ Have a good day|             │  ← text area (4 lines max)
///     │ ──────────────────────────── │  ← faint rules, decorative
///     │ ──────────────────────────── │
///     │ [#daily]                     │  ← tag chip
///     └──────────────────────────────┘
struct NoteCardContent<TextArea: View>: View {
    var icon: NoteIcon
    var date: Date
    var tag: String
    var onTagTap: (() -> Void)? = nil
    /// The fold hides the header icon (keeping its slot) while its own copy
    /// lifts off the card — one travelling view, no cross-fade.
    var showsHeaderIcon: Bool = true
    @ViewBuilder var textArea: TextArea

    // Geometry measured from the reference (points, 393pt phone).
    static var size: CGSize { CGSize(width: 236, height: 258) }
    static var inset: CGFloat { 14 }
    /// Top of the text area; the first line's centre lands ≈ 78pt down.
    static var textTop: CGFloat { 64 }
    static var linePitch: CGFloat { 30 }
    static var maxLines: Int { 4 }
    private static var dividerY: CGFloat { 52 }
    /// Decorative rules; the last one is short (≈45% width), as in the reference.
    private static var ruleYs: [CGFloat] { [118, 148, 178, 208] }
    private static var headerLeading: CGFloat { inset - 2 }
    private static var headerTop: CGFloat { 13 }
    static var headerIconSize: CGFloat { 32 }
    static var headerIconGlow: CGFloat { 0.5 }
    /// Centre of the header icon in card coordinates (the header row is the
    /// icon's height — its two text lines are shorter).
    static var headerIconCenter: CGPoint {
        CGPoint(x: headerLeading + headerIconSize / 2, y: headerTop + headerIconSize / 2)
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)

        ZStack(alignment: .topLeading) {
            SoftSurface(shape, fill: Theme.Palette.paper, elevation: .raised)

            // Ruled lines + dashed divider
            Canvas { context, size in
                var rules = Path()
                let fullWidth = size.width - Self.inset * 2
                for (index, y) in Self.ruleYs.enumerated() {
                    let width = index == Self.ruleYs.count - 1 ? fullWidth * 0.45 : fullWidth
                    rules.move(to: CGPoint(x: Self.inset, y: y))
                    rules.addLine(to: CGPoint(x: Self.inset + width, y: y))
                }
                context.stroke(rules, with: .color(Theme.Palette.paperRule), lineWidth: 1)

                var divider = Path()
                divider.move(to: CGPoint(x: Self.inset, y: Self.dividerY))
                divider.addLine(to: CGPoint(x: size.width - Self.inset, y: Self.dividerY))
                context.stroke(divider, with: .color(Theme.Palette.paperRule),
                               style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
            .allowsHitTesting(false)

            header
                .padding(.leading, Self.headerLeading)
                .padding(.top, Self.headerTop)

            textArea
                .frame(width: Self.size.width - Self.inset * 2, alignment: .topLeading)
                .offset(x: Self.inset, y: Self.textTop)

            tagChip
                .padding(.leading, Self.inset)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, Self.inset)
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }

    private var header: some View {
        HStack(spacing: 8) {
            StackedIconView(icon: icon, size: Self.headerIconSize, shapeOverride: .squircle,
                            glow: Self.headerIconGlow)
                .opacity(showsHeaderIcon ? 1 : 0)
            VStack(alignment: .leading, spacing: 1) {
                Text(NoteCardFormat.heading(for: date))
                    .font(.softNoteHeading)
                    .foregroundStyle(Theme.Palette.ink)
                Text(NoteCardFormat.timestamp(for: date))
                    .font(.softNoteMeta)
                    .foregroundStyle(Theme.Palette.inkSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var tagChip: some View {
        let label = Text("#" + tag.lowercased())
            .font(.softNoteTag)
            .foregroundStyle(Theme.Palette.inkSecondary)
            .padding(.horizontal, 8)
            .frame(height: 20)
            .background(Capsule().fill(Theme.Palette.paperTag))
            .contentTransition(.interpolate)

        if let onTagTap {
            Button(action: onTagTap) { label }
                .buttonStyle(.pressable(scale: 0.92))
                .accessibilityLabel("Tag: \(tag)")
                .accessibilityHint("Cycles to the next tag: Daily, Work, Errands, Ideas")
                .accessibilityIdentifier("tagChip")
        } else {
            label
        }
    }
}

// MARK: - Heading & timestamp

enum NoteCardFormat {
    /// "Morning note" 5–12h, "Afternoon note" 12–17h, "Evening note" 17–21h,
    /// otherwise "Night note" — derived from the time, never typed.
    static func heading(for date: Date, calendar: Calendar = .current) -> String {
        switch calendar.component(.hour, from: date) {
        case 5..<12:  "Morning note"
        case 12..<17: "Afternoon note"
        case 17..<21: "Evening note"
        default:      "Night note"
        }
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "d MMM · H:mm"          // "28 Sep · 9:41"
        return formatter
    }()

    static func timestamp(for date: Date) -> String { timestampFormatter.string(from: date) }
}

extension NoteCardContent where TextArea == NoteCardStaticText {
    /// Read-only card (Save / Fold): shows `text` in the text area.
    init(icon: NoteIcon, date: Date, tag: String, text: String, showsHeaderIcon: Bool = true) {
        self.init(icon: icon, date: date, tag: tag, showsHeaderIcon: showsHeaderIcon) {
            NoteCardStaticText(text: text)
        }
    }
}

/// The text area when the card isn't being edited — same metrics as the field.
struct NoteCardStaticText: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.softNoteText)
            .foregroundStyle(Theme.Palette.ink)
            .lineSpacing(NoteCardContent<NoteCardStaticText>.linePitch - 28.6)
            .lineLimit(NoteCardContent<NoteCardStaticText>.maxLines)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("Poses") {
    VStack(spacing: 40) {
        ForEach([NoteCardPose.resting, .review], id: \.self) { pose in
            NoteCardView(pose: pose, content: NoteCardContent(
                icon: .defaultIcon, date: .now, tag: "Daily", text: "Have a good day"))
        }
    }
    .padding(40)
    .background(Theme.Palette.canvas)
}
