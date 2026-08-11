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
        .padding(.vertical, compact ? 5 : 8)
        .padding(.horizontal, compact ? 2 : 3)
        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: compact ? 9 : 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: compact ? 9 : 12, style: .continuous).stroke(.white.opacity(0.08), lineWidth: 1))
        .shadow(color: .black.opacity(0.42), radius: 14, x: 0, y: 8)
        // Firmware/update note: visual proportions follow 3.2.00 screenshots: a black right-edge page strip with icon + tiny label for Camera/Media/Chat/Settings.
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
    private var buttonSize: CGSize { CGSize(width: compact ? 38 : 50, height: compact ? 42 : 56) }
    private var iconSize: CGFloat { compact ? 13 : 16 }

    var body: some View {
        ZStack(alignment: .trailing) {
            VStack(spacing: compact ? 2 : 3) {
                BMDAssetIcon(name: item.assetName, active: selected, fallback: item.systemImage, color: iconColor, size: iconSize)
                Text(item.title.capitalized)
                    .font(BlackmagicCamStyle.labelFont(size: compact ? 5.5 : 7, weight: .heavy))
                    .tracking(0.15)
                    .foregroundStyle(selected ? .white : .white.opacity(0.62))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
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
        // Firmware/update note: page tabs map recovered pageCamera/pageMedia/pageChat/pageSettings, pageTabWidth and tabButton size symbols; glyph names must be checked against asset_ui_names_unique.txt on firmware updates.
    }
}
