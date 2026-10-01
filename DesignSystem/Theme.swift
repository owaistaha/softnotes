import SwiftUI
import UIKit

// MARK: - Design tokens
// Values sampled directly from the reference recording (see README → "Design spec").

enum Theme {

    enum Palette {
        /// Screen background — the soft light-gray "desk" everything floats on.
        static let canvas        = Color(hex: 0xF0F0F0)
        /// Cards, rows, search button, count bubble.
        static let surface       = Color.white
        /// Recessed track behind the tab bar & the "off" toggle.
        static let track         = Color(hex: 0xE7E6E8)
        /// FAB, primary text.
        static let ink           = Color(hex: 0x17161A)
        static let inkSecondary  = Color(hex: 0x8E8C93)
        static let inkTertiary   = Color(hex: 0xC2C0C6)
        /// "Notes" toggle when on.
        static let lavenderTint  = Color(hex: 0xE2DAFF)
        static let lavenderInk   = Color(hex: 0x7B6FE0)
        /// Progress arc around the Next button in the compose flow.
        static let amber         = Color(hex: 0xF5B74A)
        /// Paper colour of the note card in the compose flow.
        static let paper         = Color(hex: 0xFFFDFA)   // sampled at 6.95 s (was a cream #FBF8EE)
        /// Tag chip on the paper card, and the card's faint ruled lines.
        static let paperTag      = Color(hex: 0xF5EFE5)
        static let paperRule     = Color.black.opacity(0.06)
        /// Folder front panel, top → bottom (fractions of the 174pt panel, tab
        /// included). Measured down the panel on the 14.0 s frame: ≈253 flat
        /// for ≈39pt below the body top, a soft ≈3-level step (the faint
        /// band), then 249 → 245 at the bottom. Was a plain white → #F5F5F6.
        static let folderFront = Gradient(stops: [
            .init(color: Color(hex: 0xFEFEFE), location: 0),
            .init(color: Color(hex: 0xFCFCFC), location: 0.36),
            .init(color: Color(hex: 0xF9F9F9), location: 0.385),
            .init(color: Color(hex: 0xF5F5F6), location: 1),
        ])
        /// Soft grey rim just inside the folder toggle's track (reference: the
        /// outer ≈2pt of the lavender track read grey, blue 255 → ≈240).
        static let toggleRim     = Color(hex: 0xDCDCE0, opacity: 0.5)
        /// Crisp 1pt edge on small round surfaces (count bubble).
        static let hairline      = Color.black.opacity(0.06)
    }

    enum Radius {
        static let row: CGFloat    = 20
        static let folder: CGFloat = 24
        static let card: CGFloat   = 22
    }

    enum Metrics {
        /// Inset of text: screen headers, section labels, compose nav.
        static let screenPadding: CGFloat = 20
        /// Inset of rows / list cards. Smaller than `screenPadding`, so rows
        /// run slightly wider than the header text (per reference).
        static let listInset: CGFloat     = 16
        /// Extra inset that brings text inside a `listInset` container back
        /// in line with `screenPadding`.
        static var listTextInset: CGFloat { screenPadding - listInset }

        static let rowHeight: CGFloat     = 58
        static let rowSpacing: CGFloat    = 6
        /// Row icon sits close to the row's left edge.
        static let rowLeading: CGFloat    = 8
        static let rowTrailing: CGFloat   = 14

        static let searchButton: CGFloat  = 46
        static let countBubble: CGFloat   = 46

        /// Round nav buttons in the compose flow.
        static let navButton: CGFloat     = 46
        /// Dynamic Type cap for measured/animated geometry (folder, tab bar + FAB,
        /// the save's card) — their text stops growing here (Step 11).
        static let geometricTypeCap: DynamicTypeSize = .xxxLarge

        // Icon picker (step 1), measured from the reference.
        static let pickerCell: CGFloat     = 70
        static let pickerSpacing: CGFloat  = 15
        static let pickerRing: CGFloat     = 80
        static let pickerRingWidth: CGFloat = 2
        static let pickerPreview: CGFloat  = 120
        /// Picker title's top gap under the nav (ref: title ink starts 72.1pt
        /// below the "New note" ink; 28.5 gave 70.6) and the preview's gap
        /// under the title (reduced by the same 1.5pt so preview and grid —
        /// which already matched within 0.2pt — stay where they were).
        static let pickerTitleTop: CGFloat   = 30
        static let pickerPreviewTop: CGFloat = 27
        static let pickerGridTop: CGFloat    = 27

        static let tabBarHeight: CGFloat  = 73
        static let tabBarInset: CGFloat   = 31
        static let tabBarPadding: CGFloat = 8
        /// Amber progress arc on the Next button: centre-line diameter. It sits
        /// *outside* the halo ring (measured: ≈ 85pt), it doesn't touch layout.
        static let fabArc: CGFloat        = 81
        static let fabArcWidth: CGFloat   = 3.5
        static let fabSize: CGFloat       = 62
        static let fabRing: CGFloat       = 5
    }

    /// The outline glyph on every stacked icon (chips, rows, tabs, picker,
    /// card header). Measured on the picker's star at the reference's
    /// resolution (1.24 px/pt): radius of gyration 5.96pt vs 5.30 at 0.32,
    /// ink ≈1.7× ours at regular weight.
    enum Glyph {
        /// Glyph point size as a fraction of the icon's size.
        static let scale: CGFloat = 0.38
        static let weight: Font.Weight = .semibold
    }

    /// Tint over the frosted front tile of a stacked icon (top-leading →
    /// bottom-trailing opacity of the tone's `light` colour).
    enum Glass {
        /// Home chips, rows, tabs, card header.
        case standard
        /// Icon picker (cells + preview): the reference's picker tiles are
        /// ≈ the `light` tone itself — mean saturation 58.8 vs 53.2 at the
        /// standard tint, same lightness. Home rows already read darker than
        /// the reference, so this is a separate case, not a token change.
        case vivid

        var tint: (top: Double, bottom: Double) {
            switch self {
            case .standard: (0.70, 0.40)
            case .vivid:    (1.0, 0.95)
            }
        }
    }

    /// One place to tune the whole app's physics.
    enum Motion {
        /// Tab pill, toggle knob, small UI state.
        static let snappy = Animation.spring(duration: 0.35, bounce: 0.25)
        /// Screen-level transitions (Home ↔ Compose).
        static let smooth = Animation.spring(duration: 0.55, bounce: 0.12)
        /// Things landing: chips, new rows, the folder receiving a note.
        static let bouncy = Animation.spring(duration: 0.6, bounce: 0.38)
        /// Returning from a drag (folder tilt).
        static let release = Animation.spring(duration: 0.7, bounce: 0.45)
        /// Layout that follows the software keyboard (write step). Close to
        /// the keyboard's own ~0.35 s curve, so the card and keys move together.
        static let keyboard = Animation.spring(duration: 0.4, bounce: 0)

        // 05 Save / 06 Fold — measured at 60 fps (see `FoldTimeline`).
        /// The card flying from the write step to the centre, straightening
        /// and un-growing while the keyboard drops (≈0.35 s, no overshoot).
        static let settle = Animation.spring(duration: 0.35, bounce: 0)
        /// The icon lifting off the card header onto the card's top edge
        /// (≈0.24 s, fast start, ~1pt overshoot).
        static let lift = Animation.spring(duration: 0.28, bounce: 0.12)
        /// Nav bar and title blurring away (≈0.2 s).
        static let clear = Animation.easeIn(duration: 0.2)
        /// Next dropping off the bottom edge (reference ≈0.15 s).
        static let drop = Animation.easeIn(duration: 0.18)
        /// The top half folding over the centre line. Reference: edge-on after
        /// ≈133 ms (~11° per 60 fps frame), then a slower second half — the
        /// flap's flared edges stay visible ≈130–180 ms. Near-linear to 90°,
        /// then easing out (measured on video: 0.25 s linear-ish was ~25% too
        /// fast into edge-on and hid the edges after ~50 ms).
        static let fold = Animation.timingCurve(0.3, 0.2, 0.5, 0.95, duration: 0.36)
        /// 06 push: Home rises into view (zoomed) and the folded card rises
        /// above it (reference ≈0.5–0.7 s, decelerating, no overshoot).
        static let push = Animation.spring(duration: 0.55, bounce: 0)
        /// 06 push, the card's second short rise (reference ≈0.18 s, −26pt).
        static let pushStep = Animation.spring(duration: 0.3, bounce: 0)
        /// 06 drop: the card slides behind the front panel and the icon
        /// flies into the chip slot (reference ≈0.24 s, ease-in-out).
        static let dropIn = Animation.timingCurve(0.45, 0, 0.35, 1, duration: 0.24)
        /// 07: Home zooms back to ×1 (reference ≈0.57 s).
        static let zoomOut = Animation.spring(duration: 0.6, bounce: 0)
        /// 07: header, Recent and tab bar fading/focusing back in (≈0.3 s).
        static let chromeIn = Animation.easeOut(duration: 0.3)
        /// Reduce Motion stand-in for the whole save → fold → file sequence.
        static let crossFade = Animation.easeInOut(duration: 0.25)
    }
}

// MARK: - Pastel tones (icon colours)

enum PastelTone: String, CaseIterable, Codable, Identifiable, Hashable {
    case lavender, pink, blue, orange, green, yellow, indigo

    var id: String { rawValue }

    /// Saturated back tile. Calibrated against the reference picker (4.1 s):
    /// each value = previous token + (reference rendered − ours rendered),
    /// sampled on the back tile's uncovered band. Lavender turns more violet
    /// and green more yellow-green; the rest deepen.
    var base: Color {
        switch self {
        case .lavender: Color(hex: 0x9E81F6)
        case .pink:     Color(hex: 0xF77696)
        case .blue:     Color(hex: 0x5A9AF6)
        case .orange:   Color(hex: 0xFB9A4B)
        case .green:    Color(hex: 0x63C36C)
        case .yellow:   Color(hex: 0xFFBF55)
        case .indigo:   Color(hex: 0x837AF1)
        }
    }

    /// Selection / pressed ring: the base tone darkened ~25% (sampled from the
    /// reference: blue ring ≈ #5480B6, pink ≈ #C55975).
    var ring: Color {
        switch self {
        case .lavender: Color(hex: 0x6C65BE)
        case .pink:     Color(hex: 0xBE637D)
        case .blue:     Color(hex: 0x5180BE)
        case .orange:   Color(hex: 0xBF7F49)
        case .green:    Color(hex: 0x529E73)
        case .yellow:   Color(hex: 0xBF9B45)
        case .indigo:   Color(hex: 0x5F60B9)
        }
    }

    /// Frosted front tile tint.
    var light: Color {
        switch self {
        case .lavender: Color(hex: 0xCBC6F7)
        case .pink:     Color(hex: 0xF8C2D2)
        case .blue:     Color(hex: 0xB3D2FC)
        case .orange:   Color(hex: 0xFFD6B0)
        case .green:    Color(hex: 0xBDEBD0)
        case .yellow:   Color(hex: 0xFFE7A8)
        case .indigo:   Color(hex: 0xC4C5FB)
        }
    }
}

// MARK: - Typography
// The reference uses a tight neo-grotesk. SF Pro with slight negative tracking
// is a close match; swap `design`/family here if you license a custom face.

/// Text styles (Step 11: Dynamic Type). Each has its size at the DEFAULT text
/// size (Large — what the reference was measured at) and the system text
/// style it scales with. `.softFont(_:)` turns it into a font for the current
/// Dynamic Type size through `UIFontMetrics`; at Large that is exactly
/// `Font.system(size: size, weight: weight)`, i.e. pixel-identical to the
/// fixed `Font.soft*` tokens these replaced. Geometric areas (folder, tab bar,
/// the paper card in the save) cap the size with `.dynamicTypeSize(...)`.
enum SoftType: CaseIterable {
    /// Home / Saved / All Notes header. Measured on the 14.0 s frame: "Notes"
    /// ink ≈94pt wide, cap height ≈25.6pt → 36pt (34pt gave 88 × 24.3).
    case largeTitle
    /// Compose step titles — measured ≈ 28pt with tight leading (31pt pitch).
    case title
    case headline
    /// Note row titles — one step lighter than `headline` (per reference).
    case rowTitle
    case section
    case body
    case caption
    case tabLabel
    /// Folder toggle label — measured "Notes" ink 50.2 × 13.8pt (17 medium gave 44.0 × 12.3).
    case toggleLabel
    /// "See all" on Home.
    case seeAll
    /// Compose / detail nav subtitle ("Step 1 of 2", "Tap the text to edit").
    case navSubtitle
    /// The folder's count bubble.
    case count
    // Paper note card (04 Write a chit) — measured from the reference.
    case noteText, noteHeading, noteMeta, noteTag

    /// Point size at the default Dynamic Type size (Large).
    var size: CGFloat {
        switch self {
        case .largeTitle: 36
        case .title: 28
        case .headline, .rowTitle: 16
        case .section, .body: 15
        case .seeAll: 14
        case .caption, .noteHeading: 13
        case .tabLabel, .navSubtitle: 12
        case .toggleLabel, .count: 19
        case .noteText: 24
        case .noteMeta, .noteTag: 11
        }
    }

    var weight: Font.Weight {
        switch self {
        case .largeTitle, .title: .bold
        case .headline, .section, .toggleLabel, .noteText, .noteHeading: .semibold
        case .rowTitle, .tabLabel, .noteTag: .medium
        case .body, .caption, .seeAll, .navSubtitle, .count, .noteMeta: .regular
        }
    }

    /// The system style whose growth this one follows.
    var textStyle: UIFont.TextStyle {
        switch self {
        case .largeTitle: .largeTitle
        case .title: .title1
        case .noteText: .title2
        case .toggleLabel, .count: .title3
        case .headline: .headline
        case .rowTitle, .body: .body
        case .section, .seeAll: .subheadline
        case .caption, .noteHeading: .footnote
        case .tabLabel, .navSubtitle: .caption1
        case .noteMeta, .noteTag: .caption2
        }
    }

    /// The size at a Dynamic Type size (exactly `size` at `.large`).
    func scaledSize(at dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        guard dynamicTypeSize != .large else { return size }
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(dynamicTypeSize))
        return UIFontMetrics(forTextStyle: textStyle).scaledValue(for: size, compatibleWith: traits)
    }

    func font(at dynamicTypeSize: DynamicTypeSize, weight override: Font.Weight? = nil) -> Font {
        .system(size: scaledSize(at: dynamicTypeSize), weight: override ?? weight)
    }
}

private struct SoftFontModifier: ViewModifier {
    let type: SoftType
    let weight: Font.Weight?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        content.font(type.font(at: dynamicTypeSize, weight: weight))
    }
}

extension View {
    /// The app's font for `type`, scaled for the current Dynamic Type size.
    func softFont(_ type: SoftType, weight: Font.Weight? = nil) -> some View {
        modifier(SoftFontModifier(type: type, weight: weight))
    }
}

// MARK: - Helpers

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8)  & 0xFF) / 255,
            blue:  Double(hex         & 0xFF) / 255,
            opacity: opacity
        )
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
