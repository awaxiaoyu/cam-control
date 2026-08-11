import CamControlCore
import Foundation
import SwiftUI

struct PropertyPanel: View {
    @EnvironmentObject private var controller: CameraController
    @State private var selectedCategory = "Record"

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.width < 900
            HStack(spacing: 0) {
                settingsCategoryPanel(compact: compact)
                    .frame(width: compact ? 150 : 210)
                Divider().overlay(.white.opacity(0.10))
                settingsOptionsPanel(compact: compact)
            }
            .background(BlackmagicCamStyle.canvas)
        }
        .refreshable {
            await controller.refreshProperties()
        }
        // Firmware/update note: SettingsView/RemoteHwSettingsCategoryPanel structure is reverse-derived; category glyphs use recovered CameraAppToolbox assets, and new firmware properties should be mapped into CameraPropertyKey/categoryRows instead of changing the shell.
    }

    private func settingsCategoryPanel(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Settings")
                .font(BlackmagicCamStyle.labelFont(size: compact ? 13 : 16, weight: .heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, compact ? 10 : 14)
                .padding(.top, compact ? 10 : 14)
                .padding(.bottom, compact ? 8 : 10)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(BlackmagicReverseSpec.settingsCategories, id: \.self) { category in
                        Button {
                            withAnimation(.snappy(duration: 0.16)) { selectedCategory = category }
                        } label: {
                            SettingsCategoryRow(
                                title: category,
                                subtitle: subtitle(for: category),
                                icon: icon(for: category),
                                color: color(for: category),
                                active: selectedCategory == category,
                                compact: compact
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, compact ? 4 : 6)
                .padding(.bottom, 10)
            }
        }
        .background(Color.black.opacity(0.92))
        // Firmware/update note: matches 3.2.00 Settings screenshot left rail: simple dark category list with blue active row, not iOS grouped settings chrome.
    }

    private func settingsOptionsPanel(compact: Bool) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: compact ? 10 : 14) {
                HStack {
                    Spacer()
                    Text(selectedCategory)
                        .font(BlackmagicCamStyle.labelFont(size: compact ? 12 : 16, weight: .heavy))
                        .foregroundStyle(.white)
                    Spacer()
                    BMStatusPill(title: "Props", value: "\(controller.snapshot.properties.count)", color: controller.snapshot.properties.isEmpty ? BlackmagicCamStyle.amber : BlackmagicCamStyle.okGreen)
                        .scaleEffect(compact ? 0.72 : 0.82)
                        .opacity(0.72)
                }
                .padding(.horizontal, compact ? 8 : 12)
                .padding(.top, compact ? 7 : 10)

                settingsRows(compact: compact)

                if selectedCategory == "Camera" {
                    SlateMetadataPanel(compact: compact)
                        .padding(.horizontal, compact ? 8 : 12)
                }

                if selectedCategory == "Camera" || selectedCategory == "Record" {
                    livePropertyGrid(compact: compact)
                        .padding(.horizontal, compact ? 8 : 12)
                }
            }
            .padding(.bottom, compact ? 12 : 18)
        }
        .background(Color(red: 0.035, green: 0.038, blue: 0.044))
        // Firmware/update note: right panel follows SettingsOptionsPanel screenshot: dark table, centered category title, row values right-aligned.
    }

    private func livePropertyGrid(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("CAMERA CONTROLS")
                    .font(BlackmagicCamStyle.labelFont(size: compact ? 10 : 12, weight: .heavy))
                    .tracking(1.3)
                    .foregroundStyle(BlackmagicCamStyle.cyan)
                Spacer()
                Button {
                    Task { await controller.refreshProperties() }
                } label: {
                    HStack(spacing: 7) {
                        BMDAssetIcon(name: "Sync", activeName: "Sync_active", active: true, fallback: "arrow.clockwise", color: .white, size: 13)
                        Text("REFRESH")
                    }
                    .font(BlackmagicCamStyle.labelFont(size: 10, weight: .heavy))
                    .tracking(1.0)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(.white.opacity(0.08), in: Capsule())
            }

            if controller.snapshot.properties.isEmpty {
                BMEmptyState(
                    systemImage: "slider.horizontal.3",
                    title: "No remote camera properties",
                    subtitle: "Refresh after connecting a body. Blackmagic Cam equivalent controls stay visible below from reverse-derived settings labels."
                )
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: compact ? 180 : 230), spacing: 12)], spacing: 12) {
                    ForEach(controller.snapshot.properties) { property in
                        PropertyControl(property: property, compact: compact) { value in
                            Task { await controller.setProperty(property.key, value: value) }
                        }
                    }
                }
            }
        }
        .padding(compact ? 14 : 18)
        .blackmagicPanel(cornerRadius: 22, borderOpacity: 0.16)
    }

    private func settingsRows(compact: Bool) -> some View {
        let rows = categoryRows
        return VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.title) { index, row in
                SettingsOptionRow(row: row, compact: compact)
                if index < rows.count - 1 {
                    Rectangle().fill(.white.opacity(0.07)).frame(height: 1)
                }
            }
        }
        .background(Color.black.opacity(0.26), in: RoundedRectangle(cornerRadius: compact ? 3 : 4, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: compact ? 3 : 4, style: .continuous).stroke(.white.opacity(0.07), lineWidth: 1))
        .padding(.horizontal, compact ? 8 : 12)
        // Firmware/update note: Settings rows are an OptionListView-style table; choices remain in BlackmagicReverseSpec but are not sprayed inline.
    }

    private var categoryRows: [SettingsOptionModel] {
        switch selectedCategory {
        case "Record":
            return BlackmagicReverseSpec.recordOptions.map { settingRow($0, value: valueForRecordOption($0)) }
        case "Camera":
            return BlackmagicReverseSpec.cameraOptions.map { settingRow($0, value: valueForCameraOption($0)) }
        case "Monitor":
            return BlackmagicReverseSpec.monitorOptions.map { settingRow($0, value: valueForMonitorOption($0)) }
        case "Audio":
            return BlackmagicReverseSpec.audioLabels.map { settingRow($0, value: valueForAudioOption($0)) }
        case "LUTs":
            return [
                settingRow("Display LUT", value: "On"),
                settingRow("LUT Selection", value: "Rec 709 Neutral")
            ]
        case "Media":
            return BlackmagicReverseSpec.mediaOptions.map { settingRow($0, value: valueForMediaOption($0)) }
        case "Blackmagic Cloud":
            return BlackmagicReverseSpec.cloudOptions.map { settingRow($0, value: valueForCloudOption($0)) }
        case "HDMI Out":
            return BlackmagicReverseSpec.hdmiOutOptions.map { settingRow($0, value: valueForHDMIOption($0)) }
        case "Presets":
            return BlackmagicReverseSpec.presetOptions.map { settingRow($0, value: valueForPresetOption($0)) }
        case "Accessories":
            return BlackmagicReverseSpec.accessoriesOptions.map { settingRow($0, value: valueForAccessoriesOption($0)) }
        case "Reset":
            return BlackmagicReverseSpec.resetOptions.map { settingRow($0, value: valueForResetOption($0)) } +
                BlackmagicReverseSpec.resetDialogBodies.map { SettingsOptionModel(title: "Reset Settings Dialog", value: $0, choices: [], color: BlackmagicCamStyle.recordRed) }
        default:
            return BlackmagicReverseSpec.aboutOptions.map { settingRow($0, value: valueForAboutOption($0)) }
        }
    }


    private func settingRow(_ title: String, value: String) -> SettingsOptionModel {
        SettingsOptionModel(
            title: title,
            value: value,
            choices: BlackmagicReverseSpec.settingsOptionChoices[title] ?? [],
            color: color(for: selectedCategory)
        )
        // Firmware/update note: row choices are generated from `Settings > ... > List Option` comments in F:\Blackmagic Cam_3.2.00.ipa; rerun _extract_settings_comments.py when Blackmagic changes Localizable.strings.
    }

    private func valueForAudioOption(_ title: String) -> String {
        switch title {
        case "Audio Format": return "Linear PCM"
        case "Audio Metering": return "PPM (-18dBFS)"
        case "Audio Source": return "iPhone Microphone"
        case "Record Audio as": return "Stereo"
        case "Sample Rate": return "48.0 kHz"
        default: return "Auto"
        }
    }

    private func valueForCameraOption(_ title: String) -> String {
        switch title {
        case "Shutter Measurement": return "Speed"
        case "Trigger Record Indicator": return "Beeper and Flash"
        case "Use Volume Button to Trigger Record", "Lock White Balance on Record", "Lock Current Orientation": return "On"
        default: return "Off"
        }
    }

    private func valueForRecordOption(_ title: String) -> String {
        switch title {
        case "Codec": return "Apple ProRes 422"
        case "Resolution": return "4K"
        case "Color Space": return "Rec.709"
        case "Timecode Display": return "Record Run"
        case "If Media Drops Frame": return "Alert"
        case "Capture 1 Frame Every": return "Off"
        case "Timelapse Recording": return "Off"
        default: return "On"
        }
    }

    private func valueForMonitorOption(_ title: String) -> String {
        switch title {
        case "Focus Assist Color": return "Blue"
        case "Guides Color": return "White"
        case "Guides Opacity": return "60%"
        case "HDMI Out": return "Status Text"
        default: return "On"
        }
    }

    private func valueForMediaOption(_ title: String) -> String {
        switch title {
        case "Save Clips to": return "In-App Only"
        case "Upload Clips": return "Proxies Only"
        case "Filename Convention": return "Blackmagic Camera"
        case "Auto Upload To Selected Project": return "Off"
        default: return "On"
        }
    }

    private func valueForCloudOption(_ title: String) -> String {
        switch title {
        case "Available Cloud Projects": return "No project selected - All Clips"
        case "Log in to Blackmagic Cloud": return "Offline"
        default: return "--"
        }
    }

    private func valueForHDMIOption(_ title: String) -> String {
        switch title {
        case "Clean Feed": return "Off"
        case "Mirror Display": return "On"
        case "Status Text": return "On"
        case "Status Text Surrounds Image": return "Off"
        default: return "Off"
        }
    }

    private func valueForPresetOption(_ title: String) -> String {
        switch title {
        case "Preset Selection": return "No preset selected"
        case "Sync Presets to Cloud Project": return "Manual"
        default: return "Ready"
        }
        // Firmware/update note: these rows mirror Settings > Presets / Preset Selection localization comments; update BlackmagicReverseSpec before changing values for a new IPA.
    }

    private func valueForAccessoriesOption(_ title: String) -> String {
        switch title {
        case "Nucleus Wireless Lens Control": return "Disconnected"
        case "Use Bluetooth": return "Off"
        default: return "--"
        }
    }

    private func valueForAboutOption(_ title: String) -> String {
        switch title {
        case "App Version": return "3.2.00"
        case "Learn More at Blackmagicdesign.com": return "Blackmagic Design"
        default: return "--"
        }
        // Firmware/update note: About/Accessories rows mirror Settings > About and Settings > Accessories localization comments from Blackmagic Cam 3.2.00.
    }

    private func valueForResetOption(_ title: String) -> String {
        switch title {
        case "Reset Blackmagic Cam Settings": return "Reset Camera and Cloud Settings"
        default: return "Reset"
        }
        // Firmware/update note: Reset rows mirror Settings > Reset / Reset Settings Dialog localization comments; if Blackmagic changes destructive-copy text, update BlackmagicReverseSpec.resetChoices/resetDialogBodies from Localizable.strings first.
    }

    private func propertyText(_ key: CameraPropertyKey, fallback: String) -> String {
        guard let property = controller.snapshot.properties.first(where: { $0.key == key }) else { return fallback }
        return PropertyValueFormatter.displayValue(property.value, for: key)
    }

    private func subtitle(for category: String) -> String {
        switch category {
        case "Record": return "Codec / Resolution / FPS"
        case "Camera": return "Lens / Exposure / Stabilization"
        case "Monitor": return "LUT / Guides / False Color"
        case "Audio": return "Gain / Source / Meters"
        case "LUTs": return "Display LUT / Import LUT"
        case "Media": return "Storage / Upload / Filename"
        case "Blackmagic Cloud": return "Project / Chat / Sync"
        case "HDMI Out": return "Clean Feed / Mirror Display"
        case "Reset": return "Camera / Cloud / All Content"
        default: return "Presets / Accessories / About"
        }
    }

    private func description(for category: String) -> String {
        switch category {
        case "Record": return "Codec, resolution, frame rate and media drop behavior."
        case "Camera": return "Operator camera controls for lens, shutter, iris, ISO, white balance, tint and stabilization."
        case "Monitor": return "Image monitoring overlays: histogram, audio meters, storage, focus assist, guides, zebra and clean feed."
        case "Audio": return "Audio source, gain, metering and format controls."
        case "LUTs": return "LUT selection, color space tags, display LUT and import controls."
        case "Media": return "Media storage, upload status and proxy/original upload behavior."
        case "Blackmagic Cloud": return "Project library, chat, upload, organization and remote camera control shell."
        case "HDMI Out": return "External monitor behavior including clean feed and mirror display."
        case "Reset": return "Reset Camera Settings, Camera and Cloud Settings, or all app content with the recovered Blackmagic warning copy."
        default: return "Additional Blackmagic Camera settings."
        }
    }

    private func icon(for category: String) -> String {
        switch category {
        case "Record": return "Record"
        case "Camera": return "Camera"
        case "Monitor": return "HdmiHistogramRgb"
        case "Audio": return "IconStream"
        case "LUTs": return "IconLut"
        case "Media": return "Media"
        case "Blackmagic Cloud": return "Cloud"
        case "HDMI Out": return "HdmiPlay"
        case "Presets": return "Sync"
        case "Accessories": return "ControlIcon"
        case "Reset": return "Record"
        default: return "ControlIcon"
        }
    }

    private func color(for category: String) -> Color {
        switch category {
        case "Record": return BlackmagicCamStyle.recordRed
        case "Camera": return BlackmagicCamStyle.activeBlue
        case "Monitor": return BlackmagicCamStyle.cyan
        case "Audio": return BlackmagicCamStyle.okGreen
        case "LUTs": return BlackmagicCamStyle.amber
        case "Media": return .white.opacity(0.82)
        case "Blackmagic Cloud": return BlackmagicCamStyle.cyan
        case "HDMI Out": return .white.opacity(0.72)
        case "Reset": return BlackmagicCamStyle.recordRed
        default: return BlackmagicCamStyle.mutedText
        }
    }
}

private struct SettingsCategoryRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let active: Bool
    let compact: Bool

    var body: some View {
        HStack(spacing: compact ? 7 : 9) {
            Rectangle()
                .fill(active ? BlackmagicCamStyle.activeBlue : .clear)
                .frame(width: compact ? 2 : 3, height: compact ? 18 : 22)
            Text(title)
                .font(BlackmagicCamStyle.labelFont(size: compact ? 9 : 11, weight: active ? .heavy : .bold))
                .foregroundStyle(active ? .white : .white.opacity(0.78))
                .lineLimit(1)
                .minimumScaleFactor(0.68)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, compact ? 7 : 9)
        .padding(.vertical, compact ? 7 : 9)
        .background(active ? BlackmagicCamStyle.activeBlue.opacity(0.95) : Color.clear, in: RoundedRectangle(cornerRadius: 2, style: .continuous))
        .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.06)).frame(height: 1) }
        // Firmware/update note: category row intentionally text-first like the recovered SettingsCategoryPanel screenshot; icons remain available in spec for future panel variants.
    }
}

private struct SettingsOptionModel {
    let title: String
    let value: String
    let choices: [String]
    let color: Color
}

private struct SettingsOptionRow: View {
    let row: SettingsOptionModel
    let compact: Bool

    private var isToggleRow: Bool {
        row.value == "On" || row.value == "Off"
    }

    var body: some View {
        HStack(alignment: .center, spacing: compact ? 8 : 12) {
            Text(row.title)
                .font(BlackmagicCamStyle.labelFont(size: compact ? 9 : 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.88))
                .lineLimit(1)
                .minimumScaleFactor(0.66)
            Spacer(minLength: 12)
            if isToggleRow {
                BmdSettingsToggle(on: row.value == "On", color: row.color, compact: compact)
            } else {
                Text(row.value)
                    .font(BlackmagicCamStyle.labelFont(size: compact ? 8 : 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(row.title == "Reset Settings Dialog" ? 3 : 1)
                    .multilineTextAlignment(.trailing)
                    .minimumScaleFactor(0.62)
                Image(systemName: "chevron.right")
                    .font(.system(size: compact ? 7 : 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.32))
            }
        }
        .padding(.horizontal, compact ? 10 : 14)
        .padding(.vertical, compact ? 8 : 11)
        .contentShape(Rectangle())
        // Firmware/update note: row presentation matches SettingsOptionsPanel/OptionListView table cells in Blackmagic Cam 3.2.x screenshots; selections open deeper option lists instead of inline chips.
    }
}

private struct BmdSettingsToggle: View {
    let on: Bool
    let color: Color
    let compact: Bool

    var body: some View {
        Capsule()
            .fill(on ? BlackmagicCamStyle.activeBlue : .white.opacity(0.18))
            .frame(width: compact ? 30 : 38, height: compact ? 17 : 21)
            .overlay(alignment: on ? .trailing : .leading) {
                Circle()
                    .fill(.white)
                    .frame(width: compact ? 13 : 17, height: compact ? 13 : 17)
                    .padding(2)
            }
            .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 1))
        // Firmware/update note: toggle proportions follow the Settings screenshot blue iOS-style switch used inside Blackmagic's custom dark table.
    }
}

private struct SettingsChoiceCell: View {
    let choice: String
    let selected: Bool
    let color: Color
    let compact: Bool

    var body: some View {
        HStack(spacing: compact ? 6 : 8) {
            Rectangle()
                .fill(selected ? color : .white.opacity(0.16))
                .frame(width: 2, height: compact ? 24 : 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(choice.uppercased())
                    .font(BlackmagicCamStyle.labelFont(size: compact ? 8 : 10, weight: selected ? .heavy : .bold))
                    .tracking(0.4)
                    .foregroundStyle(selected ? .white : .white.opacity(0.66))
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
                Text(selected ? "SELECTED" : "OPTION")
                    .font(BlackmagicCamStyle.labelFont(size: compact ? 5 : 6, weight: .heavy))
                    .tracking(0.7)
                    .foregroundStyle(.white.opacity(selected ? 0.54 : 0.30))
            }
        }
        .frame(minWidth: compact ? 96 : 132, alignment: .leading)
        .padding(.horizontal, compact ? 8 : 10)
        .padding(.vertical, compact ? 7 : 9)
        .background(selected ? color.opacity(0.18) : .white.opacity(0.045), in: RoundedRectangle(cornerRadius: 3, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous).stroke(selected ? color.opacity(0.42) : .white.opacity(0.08), lineWidth: 1))
        // Firmware/update note: square selector cells intentionally avoid iOS capsule styling and map to recovered OptionListView/BmdTextListSelector rows.
    }
}

private struct SlateMetadataPanel: View {
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    BMDAssetIcon(name: "Slate", activeName: "Slate_active", active: true, fallback: "clapperboard.fill", color: BlackmagicCamStyle.amber, size: compact ? 15 : 18)
                    Text("SLATE FOR")
                }
                .font(BlackmagicCamStyle.labelFont(size: compact ? 10 : 12, weight: .heavy))
                .tracking(1.4)
                .foregroundStyle(BlackmagicCamStyle.amber)
                Spacer()
                Text("Project / Clip / Lens Info")
                    .font(BlackmagicCamStyle.labelFont(size: compact ? 8 : 10, weight: .heavy))
                    .tracking(1.1)
                    .foregroundStyle(.white.opacity(0.42))
                    .lineLimit(1)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: compact ? 150 : 190), spacing: 10)], spacing: 10) {
                ForEach(BlackmagicReverseSpec.slateFields, id: \.self) { field in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(field)
                            .font(BlackmagicCamStyle.labelFont(size: compact ? 8 : 10, weight: .heavy))
                            .tracking(1.1)
                            .foregroundStyle(BlackmagicCamStyle.mutedText)
                        Text(value(for: field))
                            .font(BlackmagicCamStyle.labelFont(size: compact ? 13 : 15, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.black.opacity(0.30), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.white.opacity(0.10), lineWidth: 1))
                }
            }
        }
        .padding(compact ? 14 : 18)
        .blackmagicPanel(cornerRadius: 22, borderOpacity: 0.16)
    }

    private func value(for field: String) -> String {
        switch field {
        case "PRODUCTION NAME": return "No project selected - All Clips"
        case "DIRECTOR": return "--"
        case "CAMERA": return "A"
        case "CAMERA OPERATOR": return "Blackmagic Camera"
        case "SLATE FOR": return "A001"
        case "SCENE": return "001"
        case "TAKE": return "1"
        case "REEL": return "A"
        case "LENS DATA": return "Lens Type / Aperture / Focal Length"
        case "Good Take Last Clip": return "Off"
        case "Interior", "Exterior", "Day", "Night": return "--"
        case "Next Clip": return "A002"
        default: return "--"
        }
        // Firmware/update note: values mirror Camera > Slate > Project Info / Clip Info labels recovered from Localizable.strings.
    }
}

private struct PropertyControl: View {
    let property: CameraPropertyState
    let compact: Bool
    let onChange: (Int64) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 10 : 13) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(category.uppercased())
                        .font(BlackmagicCamStyle.labelFont(size: 9, weight: .heavy))
                        .tracking(1.1)
                        .foregroundStyle(categoryColor)
                    Text(property.key.title)
                        .font(BlackmagicCamStyle.labelFont(size: compact ? 14 : 17, weight: .heavy))
                        .foregroundStyle(.white)
                }
                Spacer()
                Text(isSettable ? "LIVE" : "LOCK")
                    .font(BlackmagicCamStyle.labelFont(size: 9, weight: .heavy))
                    .foregroundStyle(isSettable ? BlackmagicCamStyle.okGreen : BlackmagicCamStyle.mutedText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background((isSettable ? BlackmagicCamStyle.okGreen : Color.white).opacity(0.12), in: Capsule())
            }

            Text(PropertyValueFormatter.displayValue(property.value, for: property.key))
                .font(BlackmagicCamStyle.readoutFont(size: compact ? 25 : 32, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.55)

            HStack(spacing: 10) {
                Text(String(format: "PTP 0x%04X", Int(property.ptpCode)))
                    .font(BlackmagicCamStyle.readoutFont(size: 10, weight: .medium))
                    .foregroundStyle(BlackmagicCamStyle.mutedText)
                Spacer()
                control
            }
        }
        .padding(compact ? 13 : 16)
        .frame(minHeight: compact ? 142 : 160, alignment: .top)
        .background(.black.opacity(0.34), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.10), lineWidth: 1))
    }

    @ViewBuilder
    private var control: some View {
        if let values = property.descriptor?.values, !values.isEmpty, isSettable {
            Menu {
                Picker(property.key.title, selection: Binding(get: { property.value }, set: { onChange($0) })) {
                    ForEach(values, id: \.self) { value in
                        Text(PropertyValueFormatter.displayValue(value, for: property.key)).tag(value)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    BMDAssetIcon(name: "ControlIcon", active: true, fallback: "chevron.up.chevron.down", color: .white, size: 13)
                    Text("SET")
                }
                .font(BlackmagicCamStyle.labelFont(size: 10, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(BlackmagicCamStyle.activeBlue.opacity(0.28), in: Capsule())
            }
        } else {
            Text(isSettable ? "EDIT ON CAMERA" : "READ ONLY")
                .font(BlackmagicCamStyle.labelFont(size: 9, weight: .heavy))
                .foregroundStyle(BlackmagicCamStyle.mutedText)
        }
    }

    private var isSettable: Bool { property.descriptor?.isSettable == true }

    private var category: String {
        switch property.key {
        case .shutterSpeed, .aperture, .iso, .exposureCompensation, .exposureIndicator: return "Exposure"
        case .whiteBalance, .colorTemperature, .pictureStyle: return "Color"
        case .focusMode, .focusMeteringMode, .currentFocusPoint: return "Lens"
        case .batteryLevel, .availableShots: return "Status"
        case .shootingMode, .exposureMeteringMode: return "Camera"
        }
    }

    private var categoryColor: Color {
        switch category {
        case "Exposure": return BlackmagicCamStyle.amber
        case "Color": return BlackmagicCamStyle.cyan
        case "Lens": return BlackmagicCamStyle.activeBlue
        case "Status": return BlackmagicCamStyle.okGreen
        default: return BlackmagicCamStyle.recordRed
        }
    }
}

private enum PropertyValueFormatter {
    static func displayValue(_ value: Int64, for key: CameraPropertyKey) -> String {
        switch key {
        case .batteryLevel: return "\(value)%"
        case .colorTemperature: return "\(value)K"
        case .exposureCompensation: return value == 0 ? "0.0" : String(format: "%+.1f", Double(value) / 100.0)
        case .iso, .availableShots: return "\(value)"
        case .aperture:
            if value > 0, value < 1_000 { return String(format: "f%.1f", Double(value) / 100.0) }
            return rawDisplay(value)
        case .shutterSpeed:
            if value > 0, value <= 8_000 { return "1/\(value)" }
            return rawDisplay(value)
        default:
            return rawDisplay(value)
        }
    }

    private static func rawDisplay(_ value: Int64) -> String {
        "0x\(String(UInt64(bitPattern: value), radix: 16))"
    }
}
