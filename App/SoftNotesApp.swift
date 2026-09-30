import SwiftUI

@main
struct SoftNotesApp: App {
    var body: some Scene {
        WindowGroup {
            RootContainerView()
                // The soft-UI palette is designed for light mode only (for now).
                .preferredColorScheme(.light)
        }
    }
}
