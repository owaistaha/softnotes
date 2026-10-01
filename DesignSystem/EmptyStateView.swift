import SwiftUI

/// The app's empty state: a stacked icon, a headline and a short caption.
/// (Extracted from the Saved screen — same look.)
struct EmptyStateView: View {
    let icon: NoteIcon
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 14) {
            StackedIconView(icon: icon, size: 56)
            Text(title)
                .font(.softHeadline)
                .foregroundStyle(Theme.Palette.ink)
            Text(message)
                .font(.softCaption)
                .foregroundStyle(Theme.Palette.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    EmptyStateView(icon: NoteIcon(symbol: "tray", tone: .lavender), title: "No notes yet",
                   message: "Tap + on Home to write your first note.")
        .background(Theme.Palette.canvas)
}
