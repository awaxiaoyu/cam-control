import SwiftUI

/// Persistent page rail recovered from Blackmagic Cam pageCamera/pageMedia/pageChat/pageSettings navigation symbols.
/// Firmware/update note: when a new IPA adds/removes pages, update ShootingHUDNavItem and this rail together from recovered BmdTabView/BmdVTabView strings.
struct BlackmagicRootPageRail: View {
    let selection: ShootingHUDNavItem
    let compact: Bool
    let onNavigate: (ShootingHUDNavItem) -> Void

    var body: some View {
        VStack(spacing: compact ? 7 : 9) {
            ForEach(ShootingHUDNavItem.allCases) { item in
                Button { onNavigate(item) } label: {
                    RootPageRailButton(item: item, selected: item == selection, compact: compact)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, compact ? 7 : 10)
        .padding(.horizontal, compact ? 4 : 6)
        .background(.black.opacity(0.58), in: RoundedRectangle(cornerRadius: compact ? 16 : 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: compact ? 16 : 22, style: .continuous).stroke(.white.opacity(0.11), lineWidth: 1))
        .shadow(color: .black.opacity(0.40), radius: 18, x: 0, y: 10)
    }
}

private struct RootPageRailButton: View {
    let item: ShootingHUDNavItem
    let selected: Bool
    let compact: Bool

    private var iconColor: Color { selected ? .white : .white.opacity(0.64) }
    private var fillColor: Color { selected ? BlackmagicCamStyle.activeBlue.opacity(0.58) : .white.opacity(0.052) }
    private var strokeColor: Color { selected ? BlackmagicCamStyle.cyan.opacity(0.48) : .white.opacity(0.08) }
    private var cornerRadius: CGFloat { compact ? 10 : 13 }
    private var buttonSize: CGSize { CGSize(width: compact ? 40 : 50, height: compact ? 40 : 52) }
    private var iconSize: CGFloat { compact ? 18 : 22 }

    var body: some View {
        ZStack(alignment: .trailing) {
            BMDAssetIcon(name: item.assetName, active: selected, fallback: item.systemImage, color: iconColor, size: iconSize)
                .frame(width: buttonSize.width, height: buttonSize.height)
                .background(fillColor, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).stroke(strokeColor, lineWidth: 1))
            if selected {
                Capsule()
                    .fill(BlackmagicCamStyle.cyan)
                    .frame(width: 3, height: compact ? 20 : 26)
                    .offset(x: compact ? 4 : 5)
            }
        }
        .accessibilityLabel(item.title)
        // Firmware/update note: page tabs map recovered pageCamera/pageMedia/pageChat/pageSettings, pageTabWidth and tabButton size symbols; glyph names must be checked against asset_ui_names_unique.txt on firmware updates.
    }
}
