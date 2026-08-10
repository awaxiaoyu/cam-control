import CamControlCore
import Foundation
import SwiftUI

struct DeviceListView: View {
    @EnvironmentObject private var controller: CameraController
    @Binding var source: CameraSourceKind

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    heroHeader
                    permissionOnboardingStrip
                    sourceSwitcher(isWide: proxy.size.width > 760)
                    deviceStage
                }
                .padding(.horizontal, proxy.size.width > 760 ? 36 : 18)
                .padding(.vertical, proxy.size.width > 760 ? 30 : 18)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(BlackmagicCamStyle.studioGradient.ignoresSafeArea())
        }
        .navigationTitle("CamControl")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            Button {
                controller.startBrowsing()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .foregroundStyle(.white)
            }
            .accessibilityLabel("Refresh cameras")
        }
        // Firmware/update note: source/device cards read CameraSourceKind and CameraDevice directly; update those models when camera firmware adds vendors or capabilities.
    }

    private var heroHeader: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Text("CAMCONTROL")
                        .font(BlackmagicCamStyle.labelFont(size: 12, weight: .heavy))
                        .tracking(2.2)
                        .foregroundStyle(BlackmagicCamStyle.cyan)
                    Text("USB / PHONE")
                        .font(BlackmagicCamStyle.labelFont(size: 11, weight: .heavy))
                        .tracking(1.4)
                        .foregroundStyle(BlackmagicCamStyle.mutedText)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.08), in: Capsule())
                }
                Text("Camera control room")
                    .font(BlackmagicCamStyle.labelFont(size: 36, weight: .heavy))
                    .foregroundStyle(.white)
                Text("A Blackmagic Cam inspired control surface for tethered still cameras and the built-in iPhone camera.")
                    .font(BlackmagicCamStyle.labelFont(size: 14, weight: .medium))
                    .foregroundStyle(BlackmagicCamStyle.mutedText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            BMStatusPill(title: "Status", value: statusText, color: statusColor)
        }
    }

    private var permissionOnboardingStrip: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "checklist.checked")
                    .foregroundStyle(BlackmagicCamStyle.cyan)
                Text("TO GET STARTED, BLACKMAGIC CAMERA NEEDS ACCESS TO:")
                    .font(BlackmagicCamStyle.labelFont(size: 11, weight: .heavy))
                    .tracking(1.2)
                    .foregroundStyle(BlackmagicCamStyle.mutedText)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                PermissionChip(title: "Camera", subtitle: "Preview / Capture", icon: "camera.fill", color: BlackmagicCamStyle.activeBlue)
                PermissionChip(title: "Microphone", subtitle: "Audio Meters", icon: "mic.fill", color: BlackmagicCamStyle.okGreen)
                PermissionChip(title: "Photo Library", subtitle: "Save / View", icon: "photo.fill", color: BlackmagicCamStyle.cyan)
                PermissionChip(title: "Location", subtitle: "Clip Metadata", icon: "location.fill", color: BlackmagicCamStyle.amber)
                PermissionChip(title: "Local Network", subtitle: "Remote Control", icon: "network", color: BlackmagicCamStyle.recordRed)
            }
        }
        .padding(16)
        .blackmagicPanel(cornerRadius: 22)
        // Firmware/update note: onboarding permissions mirror the reversed Blackmagic strings; add new rows only if platform/firmware features require new capabilities.
    }

    @ViewBuilder
    private func sourceSwitcher(isWide: Bool) -> some View {
        let cards = ForEach(CameraSourceKind.allCases) { kind in
            Button {
                source = kind
            } label: {
                SourceCard(source: kind, isSelected: source == kind)
            }
            .buttonStyle(.plain)
        }

        if isWide {
            HStack(spacing: 14) { cards }
        } else {
            VStack(spacing: 14) { cards }
        }
    }

    @ViewBuilder
    private var deviceStage: some View {
        if source == .tethered {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    BMSectionHeader(
                        eyebrow: "Input",
                        title: "Connected cameras",
                        subtitle: "ImageCaptureCore discovery mirrors Blackmagic's camera-first launch flow."
                    )
                    Spacer(minLength: 12)
                    BMStatusPill(title: "Devices", value: "\(controller.devices.count)", color: controller.devices.isEmpty ? BlackmagicCamStyle.amber : BlackmagicCamStyle.okGreen)
                }

                if controller.devices.isEmpty {
                    BMEmptyState(
                        systemImage: "cable.connector",
                        title: "No camera detected",
                        subtitle: "Connect a Nikon, Canon, or Sony body in USB remote mode, then refresh discovery."
                    )
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 270), spacing: 14)], spacing: 14) {
                        ForEach(controller.devices) { device in
                            Button {
                                Task { await controller.connect(to: device) }
                            } label: {
                                DeviceCard(device: device, icon: icon(for: device.vendor), color: color(for: device.vendor))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 14) {
                BMSectionHeader(
                    eyebrow: "Input",
                    title: "Phone camera",
                    subtitle: "Use the same monitor HUD and shutter controls with the built-in camera."
                )
                PhoneReadyCard()
            }
        }
    }

    private var statusText: String {
        if source == .phone {
            return "Phone ready"
        }
        switch controller.status {
        case .idle: return "Idle"
        case .browsing: return "Browsing"
        case .connecting(let device): return "Connecting \(device.name)"
        case .connected(let device): return "Connected \(device.name)"
        case .failed(let message): return message
        }
    }

    private var statusColor: Color {
        switch controller.status {
        case .connected: return BlackmagicCamStyle.okGreen
        case .failed: return BlackmagicCamStyle.recordRed
        case .connecting, .browsing: return BlackmagicCamStyle.amber
        case .idle: return source == .phone ? BlackmagicCamStyle.okGreen : BlackmagicCamStyle.cyan
        }
    }

    private func icon(for vendor: CameraVendor) -> String {
        switch vendor {
        case .nikon: return "n.circle.fill"
        case .canon: return "c.circle.fill"
        case .unknown: return "camera.fill"
        }
    }

    private func color(for vendor: CameraVendor) -> Color {
        switch vendor {
        case .nikon: return BlackmagicCamStyle.amber
        case .canon: return BlackmagicCamStyle.recordRed
        case .unknown: return BlackmagicCamStyle.cyan
        }
    }
}

private struct PermissionChip: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(BlackmagicCamStyle.labelFont(size: 10, weight: .heavy))
                    .tracking(0.8)
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(BlackmagicCamStyle.labelFont(size: 10, weight: .medium))
                    .foregroundStyle(BlackmagicCamStyle.mutedText)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.10), lineWidth: 1))
    }
}

private struct SourceCard: View {
    let source: CameraSourceKind
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? BlackmagicCamStyle.activeBlue.opacity(0.18) : Color.white.opacity(0.08))
                Image(systemName: source.systemImage)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(isSelected ? BlackmagicCamStyle.cyan : .white.opacity(0.82))
            }
            .frame(width: 66, height: 66)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(source.title.uppercased())
                        .font(BlackmagicCamStyle.labelFont(size: 12, weight: .heavy))
                        .tracking(1.2)
                        .foregroundStyle(isSelected ? .white : BlackmagicCamStyle.mutedText)
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(BlackmagicCamStyle.okGreen)
                    }
                }
                Text(source.subtitle)
                    .font(BlackmagicCamStyle.labelFont(size: 13, weight: .medium))
                    .foregroundStyle(BlackmagicCamStyle.mutedText)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .blackmagicButtonShell(cornerRadius: 22, active: isSelected)
    }
}

private struct DeviceCard: View {
    let device: CameraDevice
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                Image(systemName: icon)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(color)
                Spacer()
                Text(device.vendor.rawValue.uppercased())
                    .font(BlackmagicCamStyle.labelFont(size: 11, weight: .heavy))
                    .tracking(1.3)
                    .foregroundStyle(color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(color.opacity(0.16), in: Capsule())
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(device.name)
                    .font(BlackmagicCamStyle.labelFont(size: 20, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(deviceIDLine)
                    .font(BlackmagicCamStyle.readoutFont(size: 12, weight: .medium))
                    .foregroundStyle(BlackmagicCamStyle.mutedText)
            }

            HStack {
                Text("OPEN SESSION")
                    .font(BlackmagicCamStyle.labelFont(size: 11, weight: .heavy))
                    .tracking(1.1)
                Spacer()
                Image(systemName: "arrow.right")
            }
            .foregroundStyle(.white)
        }
        .padding(18)
        .frame(minHeight: 190, alignment: .top)
        .blackmagicPanel(cornerRadius: 22)
    }

    private var deviceIDLine: String {
        let vendor = device.vendorID.map { String(format: "VID %04X", Int($0)) } ?? "VID ----"
        let product = device.productID.map { String(format: "PID %04X", Int($0)) } ?? "PID ----"
        return "\(vendor)  \(product)"
    }
}

private struct PhoneReadyCard: View {
    var body: some View {
        HStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(BlackmagicCamStyle.activeBlue.opacity(0.16))
                Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(BlackmagicCamStyle.cyan)
            }
            .frame(width: 92, height: 108)

            VStack(alignment: .leading, spacing: 9) {
                Text("Internal capture selected")
                    .font(BlackmagicCamStyle.labelFont(size: 22, weight: .heavy))
                    .foregroundStyle(.white)
                Text("Tap through to the monitor to use Blackmagic-style readouts, capture rail, histogram, storage, and audio meter widgets.")
                    .font(BlackmagicCamStyle.labelFont(size: 14, weight: .medium))
                    .foregroundStyle(BlackmagicCamStyle.mutedText)
            }
            Spacer()
        }
        .padding(20)
        .blackmagicPanel(cornerRadius: 24)
    }
}
