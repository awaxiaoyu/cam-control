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
                    VStack(spacing: compact ? 3 : 4) {
                        BMDAssetIcon(name: item.assetName, active: item == selection, fallback: item.systemImage, color: item == selection ? .white : .white.opacity(0.64), size: compact ? 17 : 20)
                        Text(item.title)
                            .font(BlackmagicCamStyle.labelFont(size: compact ? 6 : 7, weight: .heavy))
                            .tracking(0.45)
                            .lineLimit(1)
                            .minimumScaleFactor(0.48)
                    }
                    .foregroundStyle(item == selection ? .white : .white.opacity(0.54))
                    .frame(width: compact ? 42 : 52, height: compact ? 42 : 54)
                    .background(item == selection ? BlackmagicCamStyle.activeBlue.opacity(0.56) : .white.opacity(0.055), in: RoundedRectangle(cornerRadius: compact ? 11 : 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: compact ? 11 : 14, style: .continuous).stroke(item == selection ? BlackmagicCamStyle.cyan.opacity(0.52) : .white.opacity(0.08), lineWidth: 1))
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
