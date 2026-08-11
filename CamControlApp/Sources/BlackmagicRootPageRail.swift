import SwiftUI

/// Persistent page rail recovered from Blackmagic Cam pageCamera/pageMedia/pageChat/pageSettings navigation symbols.
/// Firmware/update note: when a new IPA adds/removes pages, update ShootingHUDNavItem and this rail together from recovered BmdTabView/BmdVTabView strings.
struct BlackmagicRootPageRail: View {
    let selection: ShootingHUDNavItem
    let compact: Bool
    let onNavigate: (ShootingHUDNavItem) -> Void

    var body: some View {
        VStack(spacing: compact ? 8 : 11) {
            ForEach(ShootingHUDNavItem.allCases) { item in
                Button { onNavigate(item) } label: {
                    RootPageRailButton(item: item, selected: item == selection, compact: compact)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, compact ? 4 : 6)
        .padding(.horizontal, compact ? 2 : 3)
        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: compact ? 9 : 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: compact ? 9 : 12, style: .continuous).stroke(.white.opacity(0.08), lineWidth: 1))
        .shadow(color: .black.opacity(0.42), radius: 14, x: 0, y: 8)
        // Firmware/update note: visual proportions follow recovered 3.2.00 BmdVTabView/pageCamera/pageMedia/pageChat/pageSettings: a black right-edge page strip with icon-only cells, not app-style text tabs.
    }
}

private struct RootPageRailButton: View {
    let item: ShootingHUDNavItem
    let selected: Bool
    let compact: Bool

    private var iconColor: Color { selected ? .white : .white.opacity(0.64) }
    private var fillColor: Color { selected ? BlackmagicCamStyle.activeBlue.opacity(0.58) : .white.opacity(0.052) }
    private var strokeColor: Color { selected ? BlackmagicCamStyle.cyan.opacity(0.48) : .white.opacity(0.08) }
    private var cornerRadius: CGFloat { compact ? 6 : 8 }
    private var buttonSize: CGSize { CGSize(width: compact ? 36 : 48, height: compact ? 36 : 48) }
    private var iconSize: CGFloat { compact ? 16 : 20 }

    var body: some View {
        ZStack(alignment: .trailing) {
            ZStack {
                BMDAssetIcon(name: item.assetName, active: selected, fallback: item.systemImage, color: iconColor, size: iconSize)
            }
            .frame(width: buttonSize.width, height: buttonSize.height)
            .background(fillColor, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).stroke(strokeColor, lineWidth: 1))
            if selected {
                Capsule()
                    .fill(BlackmagicCamStyle.cyan)
                    .frame(width: 2, height: compact ? 22 : 28)
                    .offset(x: compact ? 3 : 4)
            }
        }
        .accessibilityLabel(item.title)
        // Firmware/update note: page tabs map recovered pageCamera/pageMedia/pageChat/pageSettings, pageTabWidth and tabButton size symbols; keep labels accessibility-only unless a future IPA exposes visible page text.
    }
}
