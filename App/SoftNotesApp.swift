import SwiftUI

@main
struct SoftNotesApp: App {
    /// One store for the process, loaded from disk here (see NotesStore).
    private let store = NotesStore.makeForLaunch()

    var body: some Scene {
        WindowGroup {
            RootContainerView(store: store)
                // The soft-UI palette is designed for light mode only (for now).
                .preferredColorScheme(.light)
                .modifier(DebugReduceMotion())
                .modifier(DebugDynamicTypeSize())
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

/// DEBUG launch argument `-dynamicTypeSize <name>` (e.g. `xxLarge`,
/// `accessibility3`): sets the text size for the whole app, for screenshot
/// tests. The system setting is used otherwise. Compiled out of release.
private struct DebugDynamicTypeSize: ViewModifier {
    func body(content: Content) -> some View {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-dynamicTypeSize"), i + 1 < args.count,
           let size = DynamicTypeSize.allCases.first(where: { "\($0)" == args[i + 1] }) {
            content.environment(\.dynamicTypeSize, size)
        } else {
            content
        }
        #else
        content
        #endif
    }
}
