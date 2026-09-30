import SwiftUI

@main
struct SoftNotesApp: App {
    var body: some Scene {
        WindowGroup {
            RootContainerView()
                // The soft-UI palette is designed for light mode only (for now).
                .preferredColorScheme(.light)
                .modifier(DebugReduceMotion())
        }
    }
}

/// DEBUG launch argument `-reduceMotion`: forces the Reduce Motion paths
/// (UI tests can't flip the system setting). Uses SwiftUI's settable
/// underscored key; compiled out of release builds.
private struct DebugReduceMotion: ViewModifier {
    func body(content: Content) -> some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-reduceMotion") {
            content.environment(\._accessibilityReduceMotion, true)
        } else {
            content
        }
        #else
        content
        #endif
    }
}
