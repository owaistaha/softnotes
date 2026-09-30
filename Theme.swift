import SwiftUI

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
        static let paper         = Color(hex: 0xFBF8EE)
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

        static let tabBarHeight: CGFloat  = 73
        static let tabBarInset: CGFloat   = 31
        static let tabBarPadding: CGFloat = 8
        static let fabSize: CGFloat       = 62
        static let fabRing: CGFloat       = 5
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
    }
}

// MARK: - Pastel tones (icon colours)

enum PastelTone: String, CaseIterable, Codable, Identifiable, Hashable {
    case lavender, pink, blue, orange, green, yellow, indigo

    var id: String { rawValue }

    /// Saturated back tile.
    var base: Color {
        switch self {
        case .lavender: Color(hex: 0x9087FD)
        case .pink:     Color(hex: 0xFD84A6)
        case .blue:     Color(hex: 0x6CABFD)
        case .orange:   Color(hex: 0xFFA962)
        case .green:    Color(hex: 0x6ED39A)
        case .yellow:   Color(hex: 0xFFCF5C)
        case .indigo:   Color(hex: 0x7E80F7)
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

extension Font {
    static let softLargeTitle = Font.system(size: 34, weight: .bold)
    static let softTitle      = Font.system(size: 24, weight: .bold)
    static let softHeadline   = Font.system(size: 16, weight: .semibold)
    /// Note row titles — one step lighter than `softHeadline` (per reference).
    static let softRowTitle   = Font.system(size: 16, weight: .medium)
    static let softSection    = Font.system(size: 15, weight: .semibold)
    static let softBody       = Font.system(size: 15, weight: .regular)
    static let softCaption    = Font.system(size: 13, weight: .regular)
    static let softTabLabel   = Font.system(size: 12, weight: .medium)
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
