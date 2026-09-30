import SwiftUI
import UIKit

/// Keeps content clear of the keyboard's *visible* top edge.
///
/// SwiftUI's keyboard safe area does the avoidance — it is the source that
/// moves in step with the keys (the iOS 26 keyboard runs out of process;
/// `keyboardWillChangeFrame` arrives ≈100–150 ms into its rise — measured on
/// video in 6B; padding driven by UIKit alone lagged the keys visibly). On
/// iOS 26 that safe area stops ≈48pt *inside* the keyboard's visible top
/// (UIKit: keyboard top y = 539, SwiftUI safe edge y = 587 on an iPhone
/// 17 Pro); this pads by the difference. Where the two agree (iOS 17.5,
/// measured in 6B) the padding is 0 — gated by the measured overlap, not by
/// OS version.
///
/// No state is written during layout (6B — the Step 4 version hung the main
/// thread). It used to store its own bottom edge from a GeometryReader
/// `onChange`; with the keyboard up the write step is taller than the space
/// left, so the padding made the view overflow and re-centre, which moved
/// the measured edge by half the padding: 587 → 611 → 623 → (cap) 0 → 587…
/// inside one `render()`, forever. Now the GeometryReader's frame is the
/// proposal itself (independent of the content), the edge is read from the
/// proxy while computing the padding, and the content is pinned to exactly
/// that frame, bottom-aligned, so overflow goes up and never resizes
/// anything (the overflow also enlarged the root ZStack and shifted the
/// whole app down while the keyboard moved).
struct KeyboardOverlapPadding: ViewModifier {
    /// Top of the keyboard's frame in screen coordinates (nil = hidden).
    /// Written only from UIKit's notifications, never from layout.
    @State private var keyboardTop: CGFloat?

    /// Only the small lip is corrected. UIKit's notification can land before
    /// SwiftUI applies its inset; in that window the raw difference is the
    /// whole keyboard and must not be applied (it squashed the nav, Step 4).
    static let maxCorrection: CGFloat = 80

    func body(content: Content) -> some View {
        GeometryReader { proxy in
            content
                .padding(.bottom, overlap(bottomEdge: proxy.frame(in: .global).maxY.rounded()))
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
            guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            let screen = (note.object as? UIScreen)?.bounds.height ?? .greatestFiniteMagnitude
            setKeyboardTop(frame.minY < screen ? frame.minY.rounded() : nil)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            setKeyboardTop(nil)
        }
    }

    private func overlap(bottomEdge: CGFloat) -> CGFloat {
        guard let keyboardTop else { return 0 }
        let raw = bottomEdge - keyboardTop
        return (0...Self.maxCorrection).contains(raw) ? raw : 0
    }

    private func setKeyboardTop(_ top: CGFloat?) {
        guard top != keyboardTop else { return }
        withAnimation(Theme.Motion.keyboard) { keyboardTop = top }
    }
}

extension View {
    func keyboardOverlapPadding() -> some View { modifier(KeyboardOverlapPadding()) }
}
