import SwiftUI
import UIKit

/// Keeps content clear of the keyboard's *visible* top edge.
///
/// Measured on iOS 26: SwiftUI's keyboard safe area stops 44pt *below* the
/// keyboard's visible top (UIKit reports the keyboard at y = 539, SwiftUI's
/// safe edge is at y = 583 on an iPhone 17 Pro), so bottom-pinned views like
/// the Next button end up half under the keys. This pads the view's bottom by
/// however far the keyboard's real frame (from UIKit's notification) overlaps
/// it — 0 when the two agree.
struct KeyboardOverlapPadding: ViewModifier {
    @State private var keyboardTop: CGFloat = .greatestFiniteMagnitude
    @State private var bottomEdge: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .padding(.bottom, overlap)
            // Measures the *outer* frame (padding is inside it), so no feedback loop.
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { bottomEdge = proxy.frame(in: .global).maxY }
                        .onChange(of: proxy.frame(in: .global).maxY) { _, maxY in bottomEdge = maxY }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
                guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
                withAnimation(Theme.Motion.keyboard) { keyboardTop = frame.minY }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation(Theme.Motion.keyboard) { keyboardTop = .greatestFiniteMagnitude }
            }
    }
}

private extension KeyboardOverlapPadding {
    /// Only the *small* discrepancy (the ~44pt glass lip) is corrected. UIKit's
    /// notification arrives ≈0.5 s before SwiftUI applies its keyboard safe
    /// area; during that window the raw difference is the whole keyboard
    /// height (~335pt), and padding by it squashed the nav (the "Step 2 of 2"
    /// subtitle vanished) and made the title overshoot. Larger values = not
    /// caught up yet → no correction.
    static let maxCorrection: CGFloat = 80

    var overlap: CGFloat {
        let raw = bottomEdge - keyboardTop
        return (0...Self.maxCorrection).contains(raw) ? raw : 0
    }
}

extension View {
    func keyboardOverlapPadding() -> some View { modifier(KeyboardOverlapPadding()) }
}
