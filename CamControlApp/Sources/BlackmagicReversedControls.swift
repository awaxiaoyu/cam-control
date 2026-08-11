import SwiftUI

/// Reusable controls named after SwiftUI symbols recovered from Blackmagic Cam 3.2.00 CameraAppToolbox.
/// Firmware/update note: if a newer IPA changes BmdPopover/BmdIndicatorIconButton/BmdTextButton/BmdTextListSelector signatures, update this file from `swiftui_view_symbols.txt` first, then adapt callers.
struct BmdIndicatorIconButton: View {
    let image: String
    var activeName: String? = nil
    var active = false
    var disabled = false
    var compact = false
    var color: Color = .white.opacity(0.76)
    var pressedColor: Color = BlackmagicCamStyle.activeBlue
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            BMDAssetIcon(name: image, activeName: activeName, active: active, fallback: BlackmagicReverseSpec.assetFallbackSystemImages[image], color: disabled ? .white.opacity(0.28) : (active ? .white : color), size: compact ? 13 : 16)
                .frame(width: compact ? 26 : 34, height: compact ? 26 : 34)
                .background(active ? pressedColor.opacity(0.68) : .black.opacity(0.24), in: RoundedRectangle(cornerRadius: compact ? 6 : 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: compact ? 6 : 8, style: .continuous).stroke(active ? BlackmagicCamStyle.cyan.opacity(0.50) : .white.opacity(0.07), lineWidth: 1))
                .contentShape(RoundedRectangle(cornerRadius: compact ? 6 : 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.62 : 1.0)
        // Firmware/update note: maps recovered BmdIndicatorIconButton(image:color:pressedColor:isDisabled:action:) and should stay icon-only for HUD/page rails.
    }
}

struct BmdTextButton: View {
    let title: String
    var active = false
    var compact = false
    var color: Color = BlackmagicCamStyle.activeBlue
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(BlackmagicCamStyle.labelFont(size: compact ? 8 : 10, weight: .heavy))
                .tracking(0.9)
                .foregroundStyle(active ? .white : .white.opacity(0.76))
                .lineLimit(1)
                .minimumScaleFactor(0.62)
                .padding(.horizontal, compact ? 9 : 12)
                .padding(.vertical, compact ? 6 : 8)
                .background(active ? color.opacity(0.78) : .white.opacity(0.06), in: RoundedRectangle(cornerRadius: 3, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous).stroke(active ? color.opacity(0.55) : .white.opacity(0.10), lineWidth: 1))
        }
        .buttonStyle(.plain)
        // Firmware/update note: maps recovered BmdTextButton/BmdTextButtonStyle; keep square-corner Blackmagic cells, not iOS capsules.
    }
}

struct BmdPopoverShell<Content: View>: View {
    let compact: Bool
    let content: Content

    init(compact: Bool, @ViewBuilder content: () -> Content) {
        self.compact = compact
        self.content = content()
    }

    var body: some View {
        content
            .padding(compact ? 13 : 18)
            .background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: compact ? 18 : 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: compact ? 18 : 24, style: .continuous).stroke(.white.opacity(0.16), lineWidth: 1))
            .shadow(color: .black.opacity(0.55), radius: 24, x: 0, y: 12)
        // Firmware/update note: maps CameraAppToolbox BmdPopover(show:xOffset:yOffset:content:) as a dark floating operator panel anchored over the monitor.
    }
}

struct BmdTextListSelector: View {
    let title: String
    let options: [String]
    let selected: String
    let compact: Bool
    var color: Color = BlackmagicCamStyle.activeBlue

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 8) {
            Text(title.uppercased())
                .font(BlackmagicCamStyle.labelFont(size: compact ? 7 : 8, weight: .heavy))
                .tracking(1.0)
                .foregroundStyle(.white.opacity(0.46))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: compact ? 5 : 7) {
                    ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                        let isSelected = option.caseInsensitiveCompare(selected) == .orderedSame || (index == 0 && selected == "--")
                        Text(option.uppercased())
                            .font(BlackmagicCamStyle.labelFont(size: compact ? 7 : 9, weight: isSelected ? .heavy : .bold))
                            .tracking(0.45)
                            .foregroundStyle(isSelected ? .white : .white.opacity(0.58))
                            .lineLimit(1)
                            .minimumScaleFactor(0.55)
                            .padding(.horizontal, compact ? 7 : 9)
                            .padding(.vertical, compact ? 5 : 6)
                            .background(isSelected ? color.opacity(0.42) : .white.opacity(0.045), in: RoundedRectangle(cornerRadius: 3, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous).stroke(isSelected ? color.opacity(0.55) : .white.opacity(0.08), lineWidth: 1))
                    }
                }
            }
        }
        .padding(.horizontal, compact ? 10 : 14)
        .padding(.vertical, compact ? 7 : 9)
        .background(.black.opacity(0.18))
        // Firmware/update note: maps OptionStringListView/BmdTextListSelector rows recovered from SettingsOptionsPanel; choices stay table-like, not inline iOS chips.
    }
}

struct AudioMeterMini: View {
    let levels: [Double]
    var compact = false

    var body: some View {
        VStack(spacing: compact ? 2 : 3) {
            ForEach(Array(levels.enumerated()), id: \.offset) { index, level in
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 1).fill(.white.opacity(0.10))
                        HStack(spacing: 0) {
                            RoundedRectangle(cornerRadius: 1).fill(BlackmagicCamStyle.okGreen).frame(width: proxy.size.width * min(level, 0.72))
                            RoundedRectangle(cornerRadius: 1).fill(BlackmagicCamStyle.amber).frame(width: proxy.size.width * max(0, min(level - 0.72, 0.16)))
                            RoundedRectangle(cornerRadius: 1).fill(BlackmagicCamStyle.recordRed).frame(width: proxy.size.width * max(0, level - 0.88))
                        }
                        Text(index == 0 ? "L" : "R")
                            .font(BlackmagicCamStyle.labelFont(size: compact ? 4 : 5, weight: .heavy))
                            .foregroundStyle(.black.opacity(0.72))
                            .padding(.leading, 2)
                    }
                }
                .frame(height: compact ? 5 : 6)
            }
        }
        // Firmware/update note: maps AudioMeterMini/AudioMetersGroup evidence; channel labels remain tiny and embedded in the meter strip.
    }
}

struct HUDCameraLightIndicator: View {
    let title: String
    let asset: String
    let active: Bool
    let compact: Bool
    var color: Color = BlackmagicCamStyle.recordRed

    var body: some View {
        HStack(spacing: compact ? 3 : 4) {
            Circle()
                .fill(active ? color : .white.opacity(0.25))
                .frame(width: compact ? 6 : 8, height: compact ? 6 : 8)
                .shadow(color: active ? color.opacity(0.72) : .clear, radius: 4)
            BMDAssetIcon(name: asset, active: active, fallback: BlackmagicReverseSpec.assetFallbackSystemImages[asset], color: active ? color : .white.opacity(0.58), size: compact ? 8 : 10)
            Text(title)
                .font(BlackmagicCamStyle.labelFont(size: compact ? 5 : 7, weight: .heavy))
                .foregroundStyle(.white.opacity(active ? 0.82 : 0.54))
        }
        // Firmware/update note: maps recovered HUDCameraLightIndicator/HUDTallyIndicator top-left state, separate from the large RecordButton.
    }
}

struct RemoteClipSyncStatusFooterView: View {
    let status: String
    let clips: Int
    let compact: Bool

    var body: some View {
        HStack(spacing: compact ? 7 : 10) {
            BMDAssetIcon(name: "MediaSync", activeName: "MediaSync_active", active: true, fallback: "arrow.clockwise", color: BlackmagicCamStyle.cyan, size: compact ? 12 : 15)
            Text("Camera > Footer > Remote Sync Clips".uppercased())
                .font(BlackmagicCamStyle.labelFont(size: compact ? 6 : 8, weight: .heavy))
                .tracking(0.75)
                .foregroundStyle(.white.opacity(0.42))
            Spacer(minLength: 8)
            Text("\(clips) Clips")
                .font(BlackmagicCamStyle.labelFont(size: compact ? 8 : 10, weight: .heavy))
                .foregroundStyle(.white.opacity(0.82))
            Text(status)
                .font(BlackmagicCamStyle.labelFont(size: compact ? 8 : 10, weight: .heavy))
                .foregroundStyle(BlackmagicCamStyle.okGreen)
        }
        .padding(.horizontal, compact ? 8 : 12)
        .padding(.vertical, compact ? 6 : 8)
        .background(.black.opacity(0.46))
        .overlay(Rectangle().fill(.white.opacity(0.08)).frame(height: 1), alignment: .top)
        // Firmware/update note: maps recovered RemoteClipSyncStatusFooterView and MediaSync/SyncFooter asset family from the IPA.
    }
}

struct LutNamesPanel: View {
    let compact: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            Text("LutNamesLandscapePanel / LutNamesPortraitPanel".uppercased())
                .font(BlackmagicCamStyle.labelFont(size: compact ? 7 : 8, weight: .heavy))
                .tracking(1.0)
                .foregroundStyle(BlackmagicCamStyle.amber)
            ForEach(BlackmagicReverseSpec.lutColorSpaces, id: \.self) { space in
                HStack(spacing: compact ? 5 : 7) {
                    Text(space)
                        .font(BlackmagicCamStyle.labelFont(size: compact ? 8 : 10, weight: .heavy))
                        .foregroundStyle(.white.opacity(0.70))
                        .frame(width: compact ? 70 : 92, alignment: .leading)
                    Text(BlackmagicReverseSpec.lutNames.prefix(compact ? 3 : 5).joined(separator: "  /  "))
                        .font(BlackmagicCamStyle.labelFont(size: compact ? 7 : 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.50))
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                }
            }
        }
        // Firmware/update note: maps LutNamesLandscapePanel/LutNamesPortraitPanel using the exact LUT color-space/name groups recovered from the IPA bundle.
    }
}
