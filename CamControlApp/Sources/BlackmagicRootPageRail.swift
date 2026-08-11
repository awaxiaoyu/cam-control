import SwiftUI

/// Persistent page rail recovered from Blackmagic Cam pageCamera/pageMedia/pageChat/pageSettings navigation symbols.
/// Firmware/update note: when a new IPA adds/removes pages, update ShootingHUDNavItem and this rail together from recovered BmdTabView/BmdVTabView strings.
struct BlackmagicRootPageRail: View {
    let selection: ShootingHUDNavItem
    let compact: Bool
    var horizontal: Bool = false
    let onNavigate: (ShootingHUDNavItem) -> Void

    var body: some View {
        Group {
            if horizontal {
                HStack(spacing: 0) {
                    ForEach(ShootingHUDNavItem.allCases) { item in
                        Button { onNavigate(item) } label: {
                            RootPageRailButton(item: item, selected: item == selection, compact: compact, horizontal: true)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, compact ? 18 : 28)
                .background(Color.black.opacity(0.96))
                .overlay(Rectangle().fill(.white.opacity(0.08)).frame(height: 1), alignment: .top)
            } else {
                VStack(spacing: compact ? 0 : 2) {
                    ForEach(ShootingHUDNavItem.allCases) { item in
                        Button { onNavigate(item) } label: {
                            RootPageRailButton(item: item, selected: item == selection, compact: compact, horizontal: false)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, compact ? 4 : 6)
                .background(Color.black.opacity(0.96))
                .overlay(Rectangle().fill(.white.opacity(0.08)).frame(width: 1), alignment: .leading)
            }
        }
        // Firmware/update note: visual proportions follow recovered 3.2.00 BmdVTabView/pageCamera/pageMedia/pageChat/pageSettings in landscape and BmdTabView bottom tabs in portrait.
    }
}

private struct RootPageRailButton: View {
    let item: ShootingHUDNavItem
    let selected: Bool
    let compact: Bool
    var horizontal: Bool = false

    private var iconColor: Color { selected ? .white : .white.opacity(0.64) }
    private var fillColor: Color { selected ? BlackmagicCamStyle.activeBlue.opacity(0.58) : .white.opacity(0.052) }
    private var strokeColor: Color { selected ? BlackmagicCamStyle.cyan.opacity(0.48) : .white.opacity(0.08) }
    private var cornerRadius: CGFloat { compact ? 6 : 8 }
    private var buttonSize: CGSize { horizontal ? CGSize(width: compact ? 54 : 68, height: compact ? 54 : 64) : CGSize(width: compact ? 54 : 68, height: compact ? 46 : 56) }
    private var iconSize: CGFloat { compact ? 17 : 21 }

    var body: some View {
        VStack(spacing: horizontal ? 4 : 0) {
            ZStack(alignment: horizontal ? .bottom : .trailing) {
                BMDAssetIcon(name: item.assetName, active: selected, fallback: item.systemImage, color: iconColor, size: iconSize)
                    .frame(width: buttonSize.width, height: horizontal ? 30 : buttonSize.height)
                    .background(selected ? BlackmagicCamStyle.activeBlue.opacity(0.46) : Color.clear, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                if selected {
                    if horizontal {
                        Capsule()
                            .fill(BlackmagicCamStyle.cyan)
                            .frame(width: 22, height: 2)
                            .offset(y: 3)
                    } else {
                        Capsule()
                            .fill(BlackmagicCamStyle.cyan)
                            .frame(width: 2, height: compact ? 24 : 30)
                            .offset(x: compact ? 4 : 5)
                    }
                }
            }
            if horizontal {
                Text(item.title.capitalized)
                    .font(BlackmagicCamStyle.labelFont(size: compact ? 6 : 8, weight: .heavy))
                    .foregroundStyle(selected ? BlackmagicCamStyle.cyan : .white.opacity(0.72))
            }
        }
        .frame(width: buttonSize.width, height: buttonSize.height)
        .contentShape(Rectangle())
        .accessibilityLabel(item.title)
        // Firmware/update note: landscape page tabs are icon-only; portrait bottom BmdTabView shows compact labels exactly like the recovered screenshots.
    }
}
