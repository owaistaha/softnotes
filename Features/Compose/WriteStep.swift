import SwiftUI

/// 04_Write_a_chit — PLACEHOLDER until Step 4 (paper card + keyboard).
struct WriteStep: View {
    let draft: ComposeDraft

    var body: some View {
        VStack(spacing: 8) {
            Text("Write step")
                .font(.softTitle)
                .tracking(-0.4)
                .foregroundStyle(Theme.Palette.ink)
            Text("The paper card comes in Step 4")
                .font(.softCaption)
                .foregroundStyle(Theme.Palette.inkTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    WriteStep(draft: ComposeDraft())
        .background(Theme.Palette.canvas)
}
