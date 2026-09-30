import SwiftUI

/// STUB for 03_Pick_an_icon → 04_Write_a_chit → 05_Save → 06_Fold.
///
/// What's real already:
/// • The nav bar ("New note / Step 1 of 3", back + close).
/// • The Next button, which is the Home FAB morphed via matched geometry,
///   with the amber step-progress arc.
/// • `folderFrame` — where the fold animation must land on Home.
///
/// Tapping Next currently files a demo note so you can watch the Home side
/// of the choreography (row insert, chip shuffle, count roll, toggle flip).
struct ComposeFlowView: View {
    let flowNamespace: Namespace.ID
    /// Global frame of the Home folder card — the fold animation's target.
    let folderFrame: CGRect
    var onClose: () -> Void
    var onSave: (Note) -> Void

    @State private var step = 1
    private let totalSteps = 3

    var body: some View {
        VStack(spacing: 0) {
            ComposeNavBar(step: step, totalSteps: totalSteps, onBack: onClose, onClose: onClose)

            Text("Select an icon\nfor your note")
                .font(.softTitle)
                .tracking(-0.4)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.Palette.ink)
                .padding(.top, 24)

            Spacer()

            Text("Icon picker & note card coming next")
                .font(.softCaption)
                .foregroundStyle(Theme.Palette.inkTertiary)

            Spacer()

            PrimaryActionButton(
                symbol: "arrow.right",
                progress: Double(step) / Double(totalSteps),
                accessibilityLabel: "Next",
                action: { onSave(.demo()) }
            )
            .matchedGeometryEffect(id: FlowID.primaryAction, in: flowNamespace)
            .padding(.bottom, 12)
        }
        .padding(.horizontal, Theme.Metrics.screenPadding)
    }
}

// MARK: - Nav bar

struct ComposeNavBar: View {
    let step: Int
    let totalSteps: Int
    var onBack: () -> Void
    var onClose: () -> Void

    var body: some View {
        HStack {
            circleButton("chevron.left", label: "Back", id: "composeBack", action: onBack)
            Spacer()
            VStack(spacing: 2) {
                Text("New note")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.Palette.ink)
                Text("Step \(step) of \(totalSteps)")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.Palette.inkSecondary)
                    .contentTransition(.numericText(value: Double(step)))
            }
            Spacer()
            circleButton("xmark", label: "Close", id: "composeClose", action: onClose)
        }
        .padding(.top, 4)
    }

    private func circleButton(_ symbol: String, label: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.Palette.ink)
                .frame(width: 36, height: 36)
                .background(SoftSurface(Circle(), elevation: .raised))
        }
        .buttonStyle(.pressable(scale: 0.9))
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }
}
