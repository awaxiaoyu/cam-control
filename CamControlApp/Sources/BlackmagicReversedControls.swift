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


struct BmdPageControl<Item: Identifiable & Equatable>: View {
    let items: [Item]
    let selection: Item
    let compact: Bool

    var body: some View {
        HStack(spacing: compact ? 3 : 4) {
            ForEach(items) { item in
                Capsule()
                    .fill(item == selection ? BlackmagicCamStyle.cyan : .white.opacity(0.24))
                    .frame(width: item == selection ? (compact ? 10 : 14) : (compact ? 4 : 5), height: compact ? 3 : 4)
            }
        }
        .accessibilityLabel("BmdPageControl")
        // Firmware/update note: maps recovered BmdPageControl(index:maxIndex:color:selected:deselected:) for pageCamera/pageMedia/pageChat/pageSettings rail state.
    }
}

struct BmdPagingView<Content: View>: View {
    let index: Int
    let maxIndex: Int
    let compact: Bool
    let content: Content

    init(index: Int, maxIndex: Int, compact: Bool, @ViewBuilder content: () -> Content) {
        self.index = index
        self.maxIndex = maxIndex
        self.compact = compact
        self.content = content()
    }

    var body: some View {
        VStack(spacing: compact ? 5 : 7) {
            content
            Text("\(index + 1)/\(maxIndex + 1)")
                .font(BlackmagicCamStyle.labelFont(size: compact ? 5 : 6, weight: .heavy))
                .tracking(0.7)
                .foregroundStyle(.white.opacity(0.34))
                .accessibilityHidden(true)
        }
        // Firmware/update note: maps recovered BmdPagingView index/maxIndex shell; actual page gestures remain routed through the explicit rail buttons until controller paging is rebuilt.
    }
}

struct TimecodeSettingsView: View {
    let selected: String
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 7 : 9) {
            HStack(spacing: 8) {
                BMDAssetIcon(name: "IconLock", active: true, fallback: "lock.fill", color: BlackmagicCamStyle.cyan, size: compact ? 12 : 15)
                Text("TimecodeSettingsView".uppercased())
                    .font(BlackmagicCamStyle.labelFont(size: compact ? 8 : 10, weight: .heavy))
                    .tracking(1.2)
                    .foregroundStyle(BlackmagicCamStyle.cyan)
                Spacer()
                Text(selected.uppercased())
                    .font(BlackmagicCamStyle.labelFont(size: compact ? 7 : 9, weight: .heavy))
                    .foregroundStyle(.white.opacity(0.58))
            }
            BmdTextListSelector(title: "Timecode Display", options: BlackmagicReverseSpec.recordTimecodeOptions, selected: selected, compact: compact, color: BlackmagicCamStyle.cyan)
        }
        .padding(compact ? 10 : 14)
        .background(.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).stroke(.white.opacity(0.08), lineWidth: 1))
        // Firmware/update note: maps Settings > Record > Timecode Display > TimecodeSettingsView and SettingsOptionTimecode recovered from the IPA.
    }
}

struct RemoteSettingsCategoryPanel: View {
    let compact: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 5 : 7) {
            Text("RemoteSettingsCategoryPanel".uppercased())
                .font(BlackmagicCamStyle.labelFont(size: compact ? 7 : 8, weight: .heavy))
                .tracking(1.1)
                .foregroundStyle(.white.opacity(0.42))
            ForEach(["Record", "Camera", "Monitor", "Audio"], id: \.self) { item in
                HStack(spacing: 6) {
                    Rectangle().fill(item == "Camera" ? BlackmagicCamStyle.activeBlue : .white.opacity(0.18)).frame(width: 2, height: compact ? 16 : 20)
                    Text(item.uppercased())
                        .font(BlackmagicCamStyle.labelFont(size: compact ? 7 : 9, weight: .heavy))
                        .foregroundStyle(item == "Camera" ? .white : .white.opacity(0.58))
                }
            }
        }
        // Firmware/update note: category names mirror recovered RemoteSettingsCategoryPanel/RemoteHwSettingsCategoryPanel; bind to actual remote capability sections when controller exposes them.
    }
}

struct RemoteSettingsOptionsPanel: View {
    let compact: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 8) {
            Text("RemoteSettingsOptionsPanel / HwSettingsOptionsPanel".uppercased())
                .font(BlackmagicCamStyle.labelFont(size: compact ? 7 : 8, weight: .heavy))
                .tracking(1.0)
                .foregroundStyle(BlackmagicCamStyle.activeBlue)
            ForEach(["Lens Correction", "Trigger Record Indicator", "Lock White Balance on Record", "Use Volume Button to Trigger Record"], id: \.self) { item in
                HStack {
                    Text(item)
                        .font(BlackmagicCamStyle.labelFont(size: compact ? 8 : 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.76))
                    Spacer()
                    Text(item.contains("Lock") ? "On" : "Off")
                        .font(BlackmagicCamStyle.labelFont(size: compact ? 7 : 9, weight: .heavy))
                        .foregroundStyle(.white.opacity(0.48))
                }
            }
        }
        // Firmware/update note: maps recovered RemoteSettingsOptionsPanel/HwSettingsOptionsPanel; values are placeholders until CameraPropertyKey writes cover these Blackmagic options.
    }
}

struct RemoteHwSettingsCategoryPanel: View {
    let compact: Bool
    var body: some View {
        HStack(alignment: .top, spacing: compact ? 10 : 14) {
            RemoteSettingsCategoryPanel(compact: compact)
                .frame(width: compact ? 94 : 126, alignment: .leading)
            Rectangle().fill(.white.opacity(0.08)).frame(width: 1)
            RemoteSettingsOptionsPanel(compact: compact)
        }
        .padding(compact ? 10 : 14)
        .background(.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).stroke(.white.opacity(0.08), lineWidth: 1))
        // Firmware/update note: this is the combined RemoteHwSettingsCategoryPanel + HwSettingsOptionsPanel shell recovered from CameraAppToolbox.
    }
}

struct CloudLoginView: View {
    let compact: Bool
    var body: some View {
        VStack(spacing: compact ? 12 : 16) {
            BMDAssetImage(name: "BmdCloudLogo", fallback: "cloud.fill", preserveOriginalColors: true)
                .frame(width: compact ? 156 : 220, height: compact ? 50 : 72)
            Text("Log in to Blackmagic Cloud to\n access your projects")
                .font(BlackmagicCamStyle.labelFont(size: compact ? 15 : 20, weight: .heavy))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
            VStack(spacing: compact ? 6 : 8) {
                Text("Email")
                    .font(BlackmagicCamStyle.labelFont(size: compact ? 8 : 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.42))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, compact ? 10 : 12)
                    .padding(.vertical, compact ? 7 : 9)
                    .background(.black.opacity(0.46), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                BmdTextButton(title: "Use Email Account", active: true, compact: compact, color: BlackmagicCamStyle.activeBlue) {}
            }
            .frame(maxWidth: compact ? 260 : 360)
            Text("CloudLoginView / BmdCloudWebPage")
                .font(BlackmagicCamStyle.labelFont(size: compact ? 6 : 8, weight: .heavy))
                .tracking(1.0)
                .foregroundStyle(.white.opacity(0.32))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.035, green: 0.039, blue: 0.045))
        // Firmware/update note: maps recovered CloudLoginView/BmdCloudWebPage and Blackmagic Cloud login copy; replace placeholder fields with DavCloud auth state without altering layout.
    }
}

struct MediaClipDetailsPortraitPanel: View {
    let compact: Bool
    let rows: [(String, String)]
    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 7 : 9) {
            Text("MediaClipDetailsPortraitPanel".uppercased())
                .font(BlackmagicCamStyle.labelFont(size: compact ? 7 : 8, weight: .heavy))
                .tracking(1.0)
                .foregroundStyle(BlackmagicCamStyle.cyan)
            ForEach(Array(rows.prefix(compact ? 4 : 6).enumerated()), id: \.offset) { _, row in
                HStack {
                    Text(row.0.uppercased())
                        .font(BlackmagicCamStyle.labelFont(size: compact ? 6 : 8, weight: .heavy))
                        .foregroundStyle(.white.opacity(0.40))
                    Spacer()
                    Text(row.1)
                        .font(BlackmagicCamStyle.labelFont(size: compact ? 8 : 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.78))
                }
            }
        }
        .padding(compact ? 10 : 14)
        .background(.black.opacity(0.38), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).stroke(.white.opacity(0.08), lineWidth: 1))
        // Firmware/update note: maps recovered MediaClipDetailsPortraitPanel; compact media view should use this instead of only the wide landscape detail panel.
    }
}
