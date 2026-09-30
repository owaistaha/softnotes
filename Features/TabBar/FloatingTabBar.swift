import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case home, saved

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:  "Home"
        case .saved: "Saved"
        }
    }

    var icon: NoteIcon {
        switch self {
        case .home:  NoteIcon(symbol: "house", tone: .lavender)
        case .saved: NoteIcon(symbol: "heart", tone: .pink)
        }
    }
}

/// Shared matched-geometry IDs between the container, tab bar and compose flow.
enum FlowID {
    /// The black FAB on Home morphs into the Next button of the compose flow.
    static let primaryAction = "primaryAction"
}

// MARK: - Floating tab bar

///   ╭──────────────────( + )──────────────────╮
///   │ ╭─────────╮                              │
///   │ │  Home   │                     Saved    │   ← white pill slides between tabs
///   │ ╰─────────╯                              │
///   ╰──────────────────────────────────────────╯
struct FloatingTabBar: View {
    @Binding var selection: AppTab
    /// Namespace owned by the container so the FAB can morph into compose UI.
    let flowNamespace: Namespace.ID
    /// Slides the track away (compose flow) while the FAB morphs elsewhere.
    var isCollapsed: Bool = false
    var onPrimaryAction: () -> Void

    @Namespace private var pillNamespace

    /// The FAB's centre sits exactly on the track's top edge (per reference),
    /// so the track is pushed down by half the FAB's outer diameter.
    private var overhang: CGFloat { PrimaryActionButton.outerDiameter / 2 }

    var body: some View {
        // Plain top-aligned ZStack (not an overlay + alignmentGuide): the FAB's
        // *layout* frame is exactly where it's drawn, which matched geometry
        // needs for the FAB → Next morph. The old alignmentGuide version
        // rendered the FAB centred inside the bar instead of overhanging it.
        ZStack(alignment: .top) {
            track
                .padding(.top, overhang)
                .offset(y: isCollapsed ? 140 : 0)
                .opacity(isCollapsed ? 0 : 1)

            if !isCollapsed {
                PrimaryActionButton(symbol: "plus", accessibilityLabel: "New note", action: onPrimaryAction)
                    .matchedGeometryEffect(id: FlowID.primaryAction, in: flowNamespace)
            }
        }
        .padding(.horizontal, Theme.Metrics.tabBarInset)
        .allowsHitTesting(!isCollapsed)
    }

    private var track: some View {
        HStack(spacing: 0) {
            tabButton(.home)
            Spacer(minLength: Theme.Metrics.fabSize + 20)
            tabButton(.saved)
        }
        .padding(Theme.Metrics.tabBarPadding)
        .frame(height: Theme.Metrics.tabBarHeight)
        .background {
            // Recessed track: inner shadows only, no bright outline (per reference).
            Capsule()
                .fill(
                    Theme.Palette.track
                        .shadow(.inner(color: .black.opacity(0.07), radius: 3, y: 2))
                        .shadow(.inner(color: .white.opacity(0.8), radius: 2, y: -1))
                )
                .shadow(color: .black.opacity(0.05), radius: 16, y: 10)
        }
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let isSelected = selection == tab

        return Button {
            guard !isSelected else { return }
            withAnimation(Theme.Motion.snappy) { selection = tab }
        } label: {
            VStack(spacing: 4) {
                StackedIconView(icon: tab.icon, size: 24, isMuted: !isSelected)
                Text(tab.title)
                    .font(.softTabLabel)
                    .fontWeight(isSelected ? .semibold : .medium)
                    .foregroundStyle(isSelected ? Theme.Palette.ink : Theme.Palette.inkSecondary)
            }
            .frame(width: 104)
            .frame(maxHeight: .infinity)
            .background {
                if isSelected {
                    SoftSurface(Capsule(), elevation: .raised)
                        .matchedGeometryEffect(id: "tabPill", in: pillNamespace)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.pressable(scale: 0.95))
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: isSelected) { _, new in new }
    }
}

// MARK: - Primary action button (FAB / Next)

/// Black disc inside a light halo ring. Used as the "+" FAB on Home and,
/// via matched geometry, as the "→" Next button in the compose flow — where an
/// amber arc shows step progress.
struct PrimaryActionButton: View {
    /// Disc + ring on both sides — the button's full layout size.
    static var outerDiameter: CGFloat { Theme.Metrics.fabSize + Theme.Metrics.fabRing * 2 }

    var symbol: String
    var progress: Double? = nil
    var accessibilityLabel: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(Theme.Palette.ink)
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(width: Theme.Metrics.fabSize, height: Theme.Metrics.fabSize)
            .padding(Theme.Metrics.fabRing)
            // Halo ring: canvas-coloured (reads lighter than the recessed track)
            // with a faint top rim. One SoftSurface (per-layer shape copies), so
            // the drop shadows don't compound like chained `.shadow()` calls.
            .background(SoftSurface(Circle(), fill: Theme.Palette.canvas, elevation: .raised))
            .overlay {
                if let progress {
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Theme.Palette.amber, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .padding(1.5)
                        .animation(Theme.Motion.smooth, value: progress)
                }
            }
        }
        .buttonStyle(.pressable(scale: 0.92))
        .accessibilityLabel(accessibilityLabel)
    }
}

#Preview {
    @Previewable @State var tab: AppTab = .home
    @Previewable @Namespace var ns
    VStack {
        Spacer()
        FloatingTabBar(selection: $tab, flowNamespace: ns) {}
    }
    .padding(.bottom, 20)
    .background(Theme.Palette.canvas)
}
