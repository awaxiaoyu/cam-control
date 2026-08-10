import CamControlCore
import Foundation
import SwiftUI

struct PropertyPanel: View {
    @EnvironmentObject private var controller: CameraController

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top, spacing: 16) {
                    BMSectionHeader(
                        eyebrow: "Configuration",
                        title: "Camera settings",
                        subtitle: "Dense, operator-facing controls modeled after Blackmagic's Exposure / Lens / Record settings hierarchy."
                    )
                    Spacer(minLength: 12)
                    BMStatusPill(title: "Props", value: "\(controller.snapshot.properties.count)", color: controller.snapshot.properties.isEmpty ? BlackmagicCamStyle.amber : BlackmagicCamStyle.okGreen)
                }

                reversedSettingsRail

                if controller.snapshot.properties.isEmpty {
                    BMEmptyState(
                        systemImage: "slider.horizontal.3",
                        title: "No properties exposed",
                        subtitle: "Refresh the session after connecting a camera in remote mode. Unsupported firmware may expose live view without editable PTP properties."
                    )
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 238), spacing: 14)], spacing: 14) {
                        ForEach(controller.snapshot.properties) { property in
                            PropertyControl(property: property) { value in
                                Task { await controller.setProperty(property.key, value: value) }
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .background(BlackmagicCamStyle.studioGradient)
        .refreshable {
            await controller.refreshProperties()
        }
        // Firmware/update note: new firmware-specific PTP properties should be added to CameraPropertyKey first; this panel automatically renders new mapped properties.
    }

    private var reversedSettingsRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                SettingsSectionChip(title: "CAMERA", subtitle: "Codec · Resolution · FPS", systemImage: "camera.fill", color: BlackmagicCamStyle.activeBlue, active: true)
                SettingsSectionChip(title: "AUDIO", subtitle: "Gain · Source · Meters", systemImage: "waveform", color: BlackmagicCamStyle.okGreen)
                SettingsSectionChip(title: "MONITOR", subtitle: "LUT · Guides · False Color", systemImage: "rectangle.inset.filled", color: BlackmagicCamStyle.cyan)
                SettingsSectionChip(title: "LUTs", subtitle: "Rec.709 · Apple Log", systemImage: "camera.filters", color: BlackmagicCamStyle.amber)
                SettingsSectionChip(title: "PRESETS", subtitle: "Import · Export · Sync", systemImage: "tray.full.fill", color: .white.opacity(0.74))
                SettingsSectionChip(title: "REMOTE", subtitle: "Camera Control · Cloud", systemImage: "dot.radiowaves.left.and.right", color: BlackmagicCamStyle.recordRed)
            }
            .padding(.vertical, 2)
        }
        // Firmware/update note: this rail mirrors reversed settings strings; when future firmware adds sections, add a chip here and bind controls below via CameraPropertyKey.
    }
}

private struct SettingsSectionChip: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let color: Color
    var active = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 34, height: 34)
                .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(title.uppercased())
                    .font(BlackmagicCamStyle.labelFont(size: 12, weight: .heavy))
                    .tracking(1.1)
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(BlackmagicCamStyle.labelFont(size: 11, weight: .medium))
                    .foregroundStyle(BlackmagicCamStyle.mutedText)
            }
        }
        .padding(14)
        .frame(width: 214, alignment: .leading)
        .blackmagicButtonShell(cornerRadius: 18, active: active)
    }
}

private struct PropertyControl: View {
    let property: CameraPropertyState
    let onChange: (Int64) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(category.uppercased())
                        .font(BlackmagicCamStyle.labelFont(size: 10, weight: .heavy))
                        .tracking(1.1)
                        .foregroundStyle(categoryColor)
                    Text(property.key.title)
                        .font(BlackmagicCamStyle.labelFont(size: 18, weight: .heavy))
                        .foregroundStyle(.white)
                }
                Spacer()
                Text(settableLabel)
                    .font(BlackmagicCamStyle.labelFont(size: 10, weight: .heavy))
                    .foregroundStyle(isSettable ? BlackmagicCamStyle.okGreen : BlackmagicCamStyle.mutedText)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background((isSettable ? BlackmagicCamStyle.okGreen : Color.white).opacity(0.12), in: Capsule())
            }

            Text(displayValue(property.value))
                .font(BlackmagicCamStyle.readoutFont(size: 32, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.55)

            HStack(spacing: 10) {
                Text(String(format: "PTP 0x%04X", Int(property.ptpCode)))
                    .font(BlackmagicCamStyle.readoutFont(size: 11, weight: .medium))
                    .foregroundStyle(BlackmagicCamStyle.mutedText)
                Spacer()
                control
            }
        }
        .padding(17)
        .frame(minHeight: 168, alignment: .top)
        .blackmagicPanel(cornerRadius: 22)
    }

    @ViewBuilder
    private var control: some View {
        if let values = property.descriptor?.values, !values.isEmpty, isSettable {
            Menu {
                Picker(property.key.title, selection: Binding(
                    get: { property.value },
                    set: { onChange($0) }
                )) {
                    ForEach(values, id: \.self) { value in
                        Text(displayValue(value)).tag(value)
                    }
                }
            } label: {
                HStack(spacing: 7) {
                    Text("SET")
                    Image(systemName: "chevron.up.chevron.down")
                }
                .font(BlackmagicCamStyle.labelFont(size: 11, weight: .heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .blackmagicButtonShell(cornerRadius: 12, active: true)
            }
        } else {
            Text(isSettable ? "EDIT ON CAMERA" : "READ ONLY")
                .font(BlackmagicCamStyle.labelFont(size: 10, weight: .heavy))
                .foregroundStyle(BlackmagicCamStyle.mutedText)
        }
    }

    private var isSettable: Bool {
        property.descriptor?.isSettable == true
    }

    private var settableLabel: String {
        isSettable ? "LIVE" : "LOCK"
    }

    private var category: String {
        switch property.key {
        case .shutterSpeed, .aperture, .iso, .exposureCompensation, .exposureIndicator:
            return "Exposure"
        case .whiteBalance, .colorTemperature, .pictureStyle:
            return "Color"
        case .focusMode, .focusMeteringMode, .currentFocusPoint:
            return "Lens"
        case .batteryLevel, .availableShots:
            return "Status"
        case .shootingMode, .exposureMeteringMode:
            return "Camera"
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

    private func displayValue(_ value: Int64) -> String {
        switch property.key {
        case .batteryLevel:
            return "\(value)%"
        case .colorTemperature:
            return "\(value)K"
        case .exposureCompensation:
            return value == 0 ? "0.0" : String(format: "%+.1f", Double(value) / 100.0)
        case .iso, .availableShots:
            return "\(value)"
        case .aperture:
            if value > 0, value < 1_000 {
                return String(format: "f%.1f", Double(value) / 100.0)
            }
            return rawDisplay(value)
        case .shutterSpeed:
            if value > 0, value <= 8_000 {
                return "1/\(value)"
            }
            return rawDisplay(value)
        default:
            return rawDisplay(value)
        }
    }

    private func rawDisplay(_ value: Int64) -> String {
        "0x\(String(UInt64(bitPattern: value), radix: 16))"
    }
}
