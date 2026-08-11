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
    private var textColor: Color { selected ? .white : .white.opacity(0.54) }
    private var fillColor: Color { selected ? BlackmagicCamStyle.activeBlue.opacity(0.56) : .white.opacity(0.055) }
    private var strokeColor: Color { selected ? BlackmagicCamStyle.cyan.opacity(0.52) : .white.opacity(0.08) }
    private var cornerRadius: CGFloat { compact ? 11 : 14 }
    private var buttonSize: CGSize { CGSize(width: compact ? 42 : 52, height: compact ? 42 : 54) }
    private var iconSize: CGFloat { compact ? 17 : 20 }
    private var labelSize: CGFloat { compact ? 6 : 7 }

    var body: some View {
        VStack(spacing: compact ? 3 : 4) {
            BMDAssetIcon(name: item.assetName, active: selected, fallback: item.systemImage, color: iconColor, size: iconSize)
            Text(item.title)
                .font(BlackmagicCamStyle.labelFont(size: labelSize, weight: .heavy))
                .tracking(0.45)
                .lineLimit(1)
                .minimumScaleFactor(0.48)
        }
        .foregroundStyle(textColor)
        .frame(width: buttonSize.width, height: buttonSize.height)
        .background(fillColor, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).stroke(strokeColor, lineWidth: 1))
        // Firmware/update note: page tabs map recovered pageCamera/pageMedia/pageChat/pageSettings, pageTabWidth and tabButton size symbols.
    }
}
