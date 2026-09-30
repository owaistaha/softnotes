import SwiftUI

// MARK: - Elevation (multi-layer soft shadows)

struct ShadowLayer: Hashable {
    var color: Color
    var radius: CGFloat
    var x: CGFloat = 0
    var y: CGFloat
}

enum Elevation {
    /// Rows, search button, count bubble.
    case raised
    /// Large floating surfaces (compose card, Next button).
    case floating
    /// The Home folder's front panel — softer and shorter than `.floating`,
    /// so the folder sits close to the canvas (per reference).
    case folder

    /// Each layer is rendered as its own shape copy (see `SoftSurface`) so the
    /// shadows don't compound the way chained `.shadow()` modifiers do.
    var layers: [ShadowLayer] {
        switch self {
        case .raised:
            [
                ShadowLayer(color: .black.opacity(0.035), radius: 1,  y: 1),
                ShadowLayer(color: .black.opacity(0.040), radius: 8,  y: 4),
                ShadowLayer(color: .black.opacity(0.045), radius: 22, y: 12),
                // Neumorphic top-left lift
                ShadowLayer(color: .white.opacity(0.90), radius: 8, x: -3, y: -3),
            ]
        case .floating:
            [
                ShadowLayer(color: .black.opacity(0.04), radius: 2,  y: 1),
                ShadowLayer(color: .black.opacity(0.06), radius: 14, y: 8),
                ShadowLayer(color: .black.opacity(0.08), radius: 36, y: 24),
                ShadowLayer(color: .white.opacity(0.95), radius: 10, x: -4, y: -4),
            ]
        case .folder:
            [
                ShadowLayer(color: .black.opacity(0.035), radius: 2,  y: 1),
                ShadowLayer(color: .black.opacity(0.045), radius: 10, y: 5),
                ShadowLayer(color: .black.opacity(0.050), radius: 24, y: 12),
                ShadowLayer(color: .white.opacity(0.95), radius: 10, x: -4, y: -4),
            ]
        }
    }
}

// MARK: - SoftSurface

/// A filled shape with stacked soft shadows and a hairline top highlight —
/// the building block of every card in the app.
struct SoftSurface<S: Shape>: View {
    var shape: S
    var fill: AnyShapeStyle
    var elevation: Elevation
    var highlight: Bool

    init(
        _ shape: S,
        fill: some ShapeStyle = Theme.Palette.surface,
        elevation: Elevation = .raised,
        highlight: Bool = true
    ) {
        self.shape = shape
        self.fill = AnyShapeStyle(fill)
        self.elevation = elevation
        self.highlight = highlight
    }

    var body: some View {
        ZStack {
            ForEach(Array(elevation.layers.enumerated()), id: \.offset) { _, layer in
                shape
                    .fill(Theme.Palette.surface)
                    .shadow(color: layer.color, radius: layer.radius, x: layer.x, y: layer.y)
            }
            shape.fill(fill)
            if highlight {
                shape.stroke(
                    LinearGradient(
                        colors: [.white, .white.opacity(0)],
                        startPoint: .top,
                        endPoint: .center
                    ),
                    lineWidth: 1
                )
            }
        }
    }
}

// MARK: - Pressable button style

struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.96

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.spring(duration: 0.25, bounce: 0.35), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    static var pressable: PressableButtonStyle { .init() }
    static func pressable(scale: CGFloat) -> PressableButtonStyle { .init(scale: scale) }
}

// MARK: - Transitions

/// The soft "focus pull" used across the reference: blur + fade + slight drift.
/// New recent rows, tab content and screen swaps all use it.
struct BlurSlideTransition: Transition {
    var blur: CGFloat = 10
    var drift: CGFloat = -14

    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .blur(radius: phase.isIdentity ? 0 : blur)
            .opacity(phase.isIdentity ? 1 : 0)
            .scaleEffect(phase.isIdentity ? 1 : 0.97)
            .offset(y: phase == .willAppear ? drift : 0)
    }
}

extension Transition where Self == BlurSlideTransition {
    static var blurSlide: BlurSlideTransition { .init() }
    static var blurFade: BlurSlideTransition { .init(blur: 14, drift: 0) }
}

// MARK: - Idle float (gentle bob for folder chips)

struct IdleFloat: ViewModifier {
    var amplitude: CGFloat = 3
    var period: Double = 2.6
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.phaseAnimator([false, true]) { view, up in
                view.offset(y: up ? -amplitude : amplitude)
            } animation: { _ in
                .easeInOut(duration: period / 2)
            }
        }
    }
}

extension View {
    func idleFloat(amplitude: CGFloat = 3, period: Double = 2.6) -> some View {
        modifier(IdleFloat(amplitude: amplitude, period: period))
    }
}
