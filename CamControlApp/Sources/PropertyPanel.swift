import CamControlCore
import Foundation
import SwiftUI

struct PropertyPanel: View {
    @EnvironmentObject private var controller: CameraController
    @State private var selectedCategory = "Camera"

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.width < 900
            HStack(spacing: 0) {
                settingsCategoryPanel(compact: compact)
                    .frame(width: compact ? 176 : 238)
                Divider().overlay(.white.opacity(0.10))
                settingsOptionsPanel(compact: compact)
            }
            .background(BlackmagicCamStyle.canvas)
        }
        .refreshable {
            await controller.refreshProperties()
        }
        // Firmware/update note: SettingsView/RemoteHwSettingsCategoryPanel structure is reverse-derived; new firmware properties should be mapped into CameraPropertyKey and categoryRows instead of changing the shell.
    }

    private func settingsCategoryPanel(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("SETTINGS")
                    .font(BlackmagicCamStyle.labelFont(size: compact ? 10 : 12, weight: .heavy))
                    .tracking(1.6)
                    .foregroundStyle(BlackmagicCamStyle.cyan)
                Text("Blackmagic Camera")
                    .font(BlackmagicCamStyle.labelFont(size: compact ? 18 : 22, weight: .heavy))
                    .foregroundStyle(.white)
                Text("Record / Camera / Monitor / Audio / LUTs")
                    .font(BlackmagicCamStyle.labelFont(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.38))
                    .lineLimit(2)
            }
            .padding(.horizontal, compact ? 12 : 18)
            .padding(.top, compact ? 14 : 20)
            .padding(.bottom, compact ? 10 : 14)

            ScrollView(showsIndicators: false) {
                VStack(spacing: compact ? 6 : 8) {
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
                .padding(.horizontal, compact ? 8 : 12)
                .padding(.bottom, 18)
            }
        }
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.92), BlackmagicCamStyle.rail.opacity(0.92)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func settingsOptionsPanel(compact: Bool) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: compact ? 16 : 22) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("SETTINGS")
                            .font(BlackmagicCamStyle.labelFont(size: compact ? 9 : 11, weight: .heavy))
                            .tracking(1.5)
                            .foregroundStyle(color(for: selectedCategory))
                        Text(selectedCategory)
                            .font(BlackmagicCamStyle.labelFont(size: compact ? 30 : 42, weight: .heavy))
                            .foregroundStyle(.white)
                        Text(description(for: selectedCategory))
                            .font(BlackmagicCamStyle.labelFont(size: compact ? 12 : 14, weight: .medium))
                            .foregroundStyle(BlackmagicCamStyle.mutedText)
                    }
                    Spacer()
                    BMStatusPill(title: "Props", value: "\(controller.snapshot.properties.count)", color: controller.snapshot.properties.isEmpty ? BlackmagicCamStyle.amber : BlackmagicCamStyle.okGreen)
                }

                if selectedCategory == "Camera" || selectedCategory == "Record" {
                    livePropertyGrid(compact: compact)
                }

                settingsRows(compact: compact)

                if selectedCategory == "Camera" {
                    SlateMetadataPanel(compact: compact)
                }
            }
            .padding(compact ? 18 : 28)
        }
        .background(BlackmagicCamStyle.studioGradient)
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
                    Label("REFRESH", systemImage: "arrow.clockwise")
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
        VStack(alignment: .leading, spacing: 10) {
            Text(selectedCategory.uppercased())
                .font(BlackmagicCamStyle.labelFont(size: compact ? 10 : 12, weight: .heavy))
                .tracking(1.3)
                .foregroundStyle(color(for: selectedCategory))

            VStack(spacing: 8) {
                ForEach(categoryRows, id: \.title) { row in
                    SettingsOptionRow(row: row, compact: compact)
                }
            }
        }
        .padding(compact ? 14 : 18)
        .blackmagicPanel(cornerRadius: 22, borderOpacity: 0.14)
    }

    private var categoryRows: [SettingsOptionModel] {
        switch selectedCategory {
        case "Record":
            return BlackmagicReverseSpec.recordOptions.map { SettingsOptionModel(title: $0, value: valueForRecordOption($0), color: color(for: selectedCategory)) }
        case "Camera":
            return BlackmagicReverseSpec.cameraOptions.map { SettingsOptionModel(title: $0, value: valueForCameraOption($0), color: color(for: selectedCategory)) }
        case "Monitor":
            return BlackmagicReverseSpec.monitorOptions.map { SettingsOptionModel(title: $0, value: valueForMonitorOption($0), color: color(for: selectedCategory)) }
        case "Audio":
            return BlackmagicReverseSpec.audioLabels.map { SettingsOptionModel(title: $0, value: $0 == "AUDIO GAIN" ? "-12 dB" : "Auto", color: color(for: selectedCategory)) }
        case "LUTs":
            return [
                SettingsOptionModel(title: "Display LUT", value: "On", color: color(for: selectedCategory)),
                SettingsOptionModel(title: "LUT Selection", value: "Rec 709 Neutral", color: color(for: selectedCategory)),
                SettingsOptionModel(title: "Color Space Tag", value: BlackmagicReverseSpec.lutColorSpaces.joined(separator: " / "), color: color(for: selectedCategory)),
                SettingsOptionModel(title: "Import LUT", value: "\(BlackmagicReverseSpec.lutNames.count) built-in names", color: color(for: selectedCategory))
            ]
        case "Media":
            return BlackmagicReverseSpec.mediaOptions.map { SettingsOptionModel(title: $0, value: valueForMediaOption($0), color: color(for: selectedCategory)) }
        case "Blackmagic Cloud":
            return BlackmagicReverseSpec.cloudOptions.map { SettingsOptionModel(title: $0, value: valueForCloudOption($0), color: color(for: selectedCategory)) }
        case "HDMI Out":
            return BlackmagicReverseSpec.hdmiOutOptions.map { SettingsOptionModel(title: $0, value: valueForHDMIOption($0), color: color(for: selectedCategory)) }
        case "Presets":
            return BlackmagicReverseSpec.presetOptions.map { SettingsOptionModel(title: $0, value: valueForPresetOption($0), color: color(for: selectedCategory)) }
        case "Accessories":
            return BlackmagicReverseSpec.accessoriesOptions.map { SettingsOptionModel(title: $0, value: valueForAccessoriesOption($0), color: color(for: selectedCategory)) }
        default:
            return BlackmagicReverseSpec.aboutOptions.map { SettingsOptionModel(title: $0, value: valueForAboutOption($0), color: color(for: selectedCategory)) }
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
        default: return "Additional Blackmagic Camera settings."
        }
    }

    private func icon(for category: String) -> String {
        switch category {
        case "Record": return "record.circle"
        case "Camera": return "camera.fill"
        case "Monitor": return "rectangle.inset.filled"
        case "Audio": return "waveform"
        case "LUTs": return "camera.filters"
        case "Media": return "photo.on.rectangle"
        case "Blackmagic Cloud": return "cloud.fill"
        case "HDMI Out": return "display"
        case "Presets": return "tray.full.fill"
        case "Accessories": return "dot.radiowaves.left.and.right"
        default: return "info.circle"
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
        HStack(spacing: compact ? 9 : 12) {
            Image(systemName: icon)
                .font(.system(size: compact ? 15 : 18, weight: .bold))
                .foregroundStyle(active ? .white : color)
                .frame(width: compact ? 30 : 36, height: compact ? 30 : 36)
                .background((active ? color : color.opacity(0.14)), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title.uppercased())
                    .font(BlackmagicCamStyle.labelFont(size: compact ? 10 : 12, weight: .heavy))
                    .tracking(0.8)
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(BlackmagicCamStyle.labelFont(size: compact ? 8 : 10, weight: .bold))
                    .foregroundStyle(.white.opacity(active ? 0.78 : 0.44))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, compact ? 9 : 12)
        .padding(.vertical, compact ? 9 : 12)
        .background(active ? color.opacity(0.22) : .white.opacity(0.045), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(active ? color.opacity(0.55) : .white.opacity(0.08), lineWidth: 1))
    }
}

private struct SettingsOptionModel {
    let title: String
    let value: String
    let color: Color
}

private struct SettingsOptionRow: View {
    let row: SettingsOptionModel
    let compact: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(row.title)
                    .font(BlackmagicCamStyle.labelFont(size: compact ? 13 : 16, weight: .heavy))
                    .foregroundStyle(.white)
                Text("Tap to select \(row.title)")
                    .font(BlackmagicCamStyle.labelFont(size: compact ? 8 : 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.38))
                    .lineLimit(1)
            }
            Spacer()
            Text(row.value.uppercased())
                .font(BlackmagicCamStyle.labelFont(size: compact ? 10 : 12, weight: .heavy))
                .tracking(0.7)
                .foregroundStyle(row.color)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(row.color.opacity(0.12), in: Capsule())
        }
        .padding(compact ? 12 : 15)
        .background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(.white.opacity(0.08), lineWidth: 1))
    }
}

private struct SlateMetadataPanel: View {
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("SLATE FOR", systemImage: "clapperboard.fill")
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
                Label("SET", systemImage: "chevron.up.chevron.down")
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
