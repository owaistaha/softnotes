import SwiftUI
import UIKit

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
    /// Detail screen: tapping the header icon opens the icon picker.
    var onIconTap: (() -> Void)? = nil
    /// The fold hides the header icon (keeping its slot) while its own copy
    /// lifts off the card — one travelling view, no cross-fade.
    var showsHeaderIcon: Bool = true
    @ViewBuilder var textArea: TextArea
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
    /// Header + tag chip stop growing here (they live in the fixed-size card).
    static var chromeCap: DynamicTypeSize { .xLarge }
    /// Centre of the header icon in card coordinates (the header row is the
    /// icon's height — its two text lines are shorter).
    static var headerIconCenter: CGPoint {
        CGPoint(x: headerLeading + headerIconSize / 2, y: headerTop + headerIconSize / 2)
    }

    private var showsRules: Bool { dynamicTypeSize <= .large }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)

        ZStack(alignment: .topLeading) {
            SoftSurface(shape, fill: Theme.Palette.paper, elevation: .raised)

            // Ruled lines + dashed divider. The rules sit on the 24pt text's lines;
            // once the note text is larger (Dynamic Type) they'd cut through it,
            // so they are only drawn at the default size or smaller.
            Canvas { [showsRules] context, size in
                var rules = Path()
                let fullWidth = size.width - Self.inset * 2
                for (index, y) in (showsRules ? Self.ruleYs : []).enumerated() {
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
                // Card chrome is card geometry (the card never grows): capped.
                .dynamicTypeSize(...Self.chromeCap)

            textArea
                .frame(width: Self.size.width - Self.inset * 2, alignment: .topLeading)
                .offset(x: Self.inset, y: Self.textTop)

            tagChip
                .dynamicTypeSize(...Self.chromeCap)
                .padding(.leading, Self.inset)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, Self.inset)
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }

    private var header: some View {
        HStack(spacing: 8) {
            headerIcon
            VStack(alignment: .leading, spacing: 1) {
                Text(NoteCardFormat.heading(for: date))
                    .softFont(.noteHeading)
                    .foregroundStyle(Theme.Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(NoteCardFormat.timestamp(for: date))
                    .softFont(.noteMeta)
                    .foregroundStyle(Theme.Palette.inkSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder
    private var headerIcon: some View {
        let glyph = StackedIconView(icon: icon, size: Self.headerIconSize, shapeOverride: .squircle,
                                    glow: Self.headerIconGlow)
            .opacity(showsHeaderIcon ? 1 : 0)

        if let onIconTap {
            Button(action: onIconTap) { glyph }
                .buttonStyle(.pressable(scale: 0.92))
                .accessibilityLabel("Icon: \(icon.accessibilityName)")
                .accessibilityHint("Opens the icon picker")
                .accessibilityIdentifier("cardIcon")
        } else {
            glyph
        }
    }

    @ViewBuilder
    private var tagChip: some View {
        let label = TagChipLabel(tag: tag)

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

/// "#daily" on its capsule. Its own view so the capsule height (a scaled
/// metric) reads the same capped Dynamic Type size as its text.
private struct TagChipLabel: View {
    let tag: String
    /// 20pt at the default size; grows with the (capped) text.
    @ScaledMetric(relativeTo: .caption2) private var height: CGFloat = 20

    var body: some View {
        Text("#" + tag.lowercased())
            .softFont(.noteTag)
            .foregroundStyle(Theme.Palette.inkSecondary)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .frame(height: height)
            .background(Capsule().fill(Theme.Palette.paperTag))
            .contentTransition(.interpolate)
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
            .modifier(NoteTextStyle(text: text))
            .foregroundStyle(Theme.Palette.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Note text size (Dynamic Type, Step 11)

/// The card's note text scales with Dynamic Type, but the card itself is fold
/// geometry and keeps its size. Rule, per text size:
/// • base = the largest size (≤ the scaled size) at which a TYPICAL full-length
///   note (48 characters, `typicalSample`) fits the text area — a constant, so
///   the text doesn't change size while you type (a focused vertical TextField
///   ignores font changes: measured at AX5, the text kept its size and scrolled);
/// • text that still doesn't fit at base (e.g. all capitals) shrinks further —
///   never below the default 24pt, at which the 48-character cap is known to fit
///   4 lines (`testTextCapAndFit`). While typing such text scrolls inside the
///   card; it fits once the field is left.
/// At the default text size this is exactly 24pt, 1.4pt line spacing, 4 lines —
/// what the fixed token gave.
enum NoteTextFit {
    static let lineSpacing: CGFloat = NoteCardContent<EmptyView>.linePitch - 28.6     // 24pt line ≈ 28.6
    /// Text area: 208pt wide (card − insets), from `textTop` to above the tag chip.
    /// Measured 10pt narrower: the vertical TextField lays text out in a text
    /// container with 5pt line padding on each side (measured with "WOW" × 12:
    /// at 208pt the fit said 3 per line, the field wrapped 2 per line and scrolled).
    static let width: CGFloat = NoteCardContent<EmptyView>.size.width - NoteCardContent<EmptyView>.inset * 2 - 10
    static let maxHeight: CGFloat = 150
    static let minimumSize: CGFloat = SoftType.noteText.size
    private static var cache: [String: CGFloat] = [:]

    /// A realistic 48-character note (the cap); sets the size for a text size.
    static let typicalSample = "Pick up the dry cleaning and call mum back about"

    /// The note text's size for `text` when the scaled (preferred) size is `preferred`.
    static func size(for text: String, preferred: CGFloat) -> CGFloat {
        guard preferred > minimumSize else { return preferred }
        let base = largestFitting(typicalSample, upTo: preferred)
        return largestFitting(text.isEmpty ? "Tap to write..." : text, upTo: base)
    }

    /// Largest size in [24pt, `limit`] at which `text` fits the text area (24pt if none does).
    private static func largestFitting(_ text: String, upTo limit: CGFloat) -> CGFloat {
        guard limit > minimumSize else { return limit }
        let key = "\(limit)|\(text)"
        if let hit = cache[key] { return hit }
        var result = minimumSize
        if fits(text, size: limit) {
            result = limit
        } else {
            var lo = minimumSize, hi = limit
            for _ in 0..<7 {
                let mid = (lo + hi) / 2
                if fits(text, size: mid) { lo = mid } else { hi = mid }
            }
            result = (lo * 2).rounded(.down) / 2
        }
        if cache.count > 300 { cache.removeAll() }
        cache[key] = result
        return result
    }

    static func lineHeight(_ size: CGFloat) -> CGFloat {
        UIFont.systemFont(ofSize: size, weight: .semibold).lineHeight + lineSpacing
    }

    /// How many lines fit the text area at `size` (4 at 24pt).
    static func maxLines(_ size: CGFloat) -> Int { max(1, Int(maxHeight / lineHeight(size))) }

    private static func fits(_ text: String, size: CGFloat) -> Bool {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = lineSpacing
        let rect = (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin],
            attributes: [.font: UIFont.systemFont(ofSize: size, weight: .semibold), .paragraphStyle: style],
            context: nil)
        return rect.height.rounded(.up) <= maxHeight
    }
}

/// Font, line spacing and line limit for the card's note text (field or static).
struct NoteTextStyle: ViewModifier {
    let text: String
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        let size = NoteTextFit.size(for: text, preferred: SoftType.noteText.scaledSize(at: dynamicTypeSize))
        content
            .font(.system(size: size, weight: SoftType.noteText.weight))
            .lineSpacing(NoteTextFit.lineSpacing)
            .lineLimit(NoteTextFit.maxLines(size))
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
