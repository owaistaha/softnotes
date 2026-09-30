import SwiftUI
import UIKit

/// Keeps content clear of the keyboard's *visible* top edge, with ONE source
/// of truth: UIKit's keyboard frame.
///
/// Why not SwiftUI's keyboard safe area: on iOS 26 it stops ≈44pt *inside*
/// the keyboard's visible top (UIKit reports the keyboard at y = 539,
/// SwiftUI's safe edge is at y = 583 on an iPhone 17 Pro) and it lags UIKit's
/// notification. The Step 4 version combined the two — SwiftUI's safe area
/// plus a padding of (measured bottom − UIKit keyboard top), capped at 80pt —
/// and the measurement was an `onChange` of a GeometryReader frame that
/// itself moved with that safe area. During a scene safe-area update the
/// state write re-ran layout, which moved the frame, which fired the
/// `onChange` again: the main thread spun inside one `render()` until
/// XCTest killed the app (6B: sampled in 2 of 8 runs, > 32 s each).
///
/// Now: the content is laid out ignoring the keyboard safe area (the call
/// site must add `.ignoresSafeArea(.keyboard)` OUTSIDE this modifier — see
/// `RootContainerView`; inside it the parent's proposal has already shrunk),
/// so its frame depends on
/// neither the keyboard nor this padding (nothing can feed back); the bottom
/// edge is measured rounded to whole points and written only when it
/// changes; the overlap is `bottomEdge − keyboardTop` from UIKit alone.
struct KeyboardOverlapPadding: ViewModifier {
    /// Top of the keyboard's frame in screen coordinates (nil = hidden).
    @State private var keyboardTop: CGFloat?
    /// Bottom of this view's frame, keyboard ignored (whole points).
    @State private var bottomEdge: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .padding(.bottom, overlap)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.frame(in: .global).maxY.rounded()
            } action: { maxY in
                if maxY != bottomEdge { bottomEdge = maxY }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
                guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
                setKeyboardTop(frame.minY < Self.screenHeight(for: note) ? frame.minY.rounded() : nil)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                setKeyboardTop(nil)
            }
    }

    private var overlap: CGFloat {
        guard let keyboardTop else { return 0 }
        return max(0, bottomEdge - keyboardTop)
    }

    private func setKeyboardTop(_ top: CGFloat?) {
        guard top != keyboardTop else { return }
        withAnimation(Theme.Motion.keyboard) { keyboardTop = top }
    }

    /// The keyboard's end frame is off-screen (minY ≥ screen height) when it
    /// is hiding.
    private static func screenHeight(for note: Notification) -> CGFloat {
        (note.object as? UIScreen)?.bounds.height
            ?? UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.screen.bounds.height }.first
            ?? .greatestFiniteMagnitude
    }
}

extension View {
    func keyboardOverlapPadding() -> some View { modifier(KeyboardOverlapPadding()) }
}
