import SwiftUI

/// 03_Pick_an_icon — minimal stand-in so Step 2 (compose state) builds on its
/// own; the real picker lands in the next commit.
struct IconPickerStep: View {
    @Bindable var draft: ComposeDraft

    var body: some View {
        Text("Select an icon\nfor your note")
            .font(.softTitle)
            .multilineTextAlignment(.center)
            .foregroundStyle(Theme.Palette.ink)
            .padding(.top, 29)
            .frame(maxWidth: .infinity)
    }
}
