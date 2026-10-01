import SwiftUI

/// The 46pt circular nav button (compose nav bar, note detail, All Notes,
/// Search): raised white disc, or a flat grey (`track`) one, 14pt medium glyph.
struct CircleNavButton: View {
    let symbol: String
    let label: String
    let id: String
    let raised: Bool
    var tint: Color? = nil
    var traits: AccessibilityTraits = []
    var value: String? = nil
    var hint: String? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(tint ?? Theme.Palette.ink)
                .frame(width: Theme.Metrics.navButton, height: Theme.Metrics.navButton)
                .background {
                    if raised {
                        SoftSurface(Circle(), elevation: .raised)
                    } else {
                        Circle().fill(Theme.Palette.track)
                    }
                }
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.pressable(scale: 0.9))
        .accessibilityLabel(label)
        .accessibilityValue(value ?? "")
        .accessibilityHint(hint ?? "")
        .accessibilityAddTraits(traits)
        .accessibilityIdentifier(id)
    }
}
