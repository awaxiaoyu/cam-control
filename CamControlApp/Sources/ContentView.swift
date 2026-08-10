import CamControlCore
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var controller: CameraController
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage("camera.source.kind") private var selectedSourceRaw = CameraSourceKind.tethered.rawValue

    var body: some View {
        Group {
            if selectedSource == .phone {
                PhoneCameraWorkspaceView()
                    .ignoresSafeArea()
            } else if case .connected = controller.status {
                CameraWorkspaceView()
                    .ignoresSafeArea()
            } else if horizontalSizeClass == .compact {
                NavigationStack {
                    DeviceListView(source: selectedSourceBinding)
                }
            } else {
                NavigationSplitView {
                    DeviceListView(source: selectedSourceBinding)
                } detail: {
                    EmptyCameraView()
                }
            }
        }
        .alert("Camera", isPresented: Binding(
            get: { controller.lastError != nil },
            set: { if !$0 { controller.clearError() } }
        )) {
            Button("OK") { controller.clearError() }
        } message: {
            Text(controller.lastError ?? "")
        }
        .task {
            applySourceSelection(selectedSource)
        }
        .onChange(of: selectedSourceRaw) { _, newValue in
            applySourceSelection(CameraSourceKind(rawValue: newValue) ?? .tethered)
        }
    }

    private var selectedSource: CameraSourceKind {
        CameraSourceKind(rawValue: selectedSourceRaw) ?? .tethered
    }

    private var selectedSourceBinding: Binding<CameraSourceKind> {
        Binding(
            get: { selectedSource },
            set: { selectedSourceRaw = $0.rawValue }
        )
    }

    private func applySourceSelection(_ source: CameraSourceKind) {
        switch source {
        case .tethered:
            controller.startBrowsing()
        case .phone:
            controller.stopBrowsing()
            Task { await controller.disconnect() }
        }
    }
}

private struct EmptyCameraView: View {
    var body: some View {
        ZStack {
            BlackmagicCamStyle.studioGradient.ignoresSafeArea()
            VStack(spacing: 24) {
                BMEmptyState(
                    systemImage: "camera.viewfinder",
                    title: "Connect a camera",
                    subtitle: "Choose a tethered Nikon, Canon, or Sony body from the input bay, or switch to the Phone camera source."
                )
                HStack(spacing: 12) {
                    BMStatusPill(title: "Mode", value: "USB / PHONE")
                    BMStatusPill(title: "HUD", value: "STBY", color: BlackmagicCamStyle.amber)
                }
            }
            .padding(24)
            .frame(maxWidth: 620)
        }
        // Firmware/update note: empty state copy should stay vendor-neutral; add new supported camera families in CameraSourceKind/CameraVendor instead of hardcoding here.
    }
}

private struct CameraWorkspaceView: View {
    @EnvironmentObject private var controller: CameraController
    @State private var selection: WorkspaceTab = .live

    var body: some View {
        Group {
            switch selection {
            case .live:
                LiveViewPanel(selectedTab: $selection)
            case .controls:
                VStack(spacing: 0) {
                    workspaceHeader(title: "Camera settings", systemImage: "slider.horizontal.3")
                    PropertyPanel()
                }
            case .gallery:
                VStack(spacing: 0) {
                    workspaceHeader(title: "Media", systemImage: "photo.on.rectangle")
                    GalleryView()
                }
            }
        }
        .background {
            if selection == .live {
                BlackmagicCamStyle.canvas
            } else {
                BlackmagicCamStyle.studioGradient
            }
        }
    }

    private func workspaceHeader(title: String, systemImage: String) -> some View {
        HStack(spacing: 14) {
            Button {
                selection = .live
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "video.fill")
                    Text("MONITOR")
                }
                .font(BlackmagicCamStyle.labelFont(size: 12, weight: .heavy))
                .tracking(1.1)
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .blackmagicButtonShell(cornerRadius: 14, active: false)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: systemImage)
                        .foregroundStyle(BlackmagicCamStyle.cyan)
                    Text(title.uppercased())
                }
                .font(BlackmagicCamStyle.labelFont(size: 13, weight: .heavy))
                .tracking(1.2)
                .foregroundStyle(.white)
                Text(deviceName + " · " + (controller.snapshot.deviceInfo?.model ?? "Ready"))
                    .font(BlackmagicCamStyle.readoutFont(size: 12, weight: .medium))
                    .foregroundStyle(BlackmagicCamStyle.mutedText)
            }
            Spacer()
            Button {
                Task { await controller.refreshProperties() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 38)
                    .blackmagicButtonShell(cornerRadius: 12)
            }
            .buttonStyle(.plain)

            Button {
                Task { await controller.capture() }
            } label: {
                HStack(spacing: 8) {
                    Circle()
                        .fill(controller.isBulbActive ? BlackmagicCamStyle.recordRed : BlackmagicCamStyle.recordRed.opacity(0.66))
                        .frame(width: 12, height: 12)
                    Text(controller.isBulbActive ? "STOP" : "CAPTURE")
                }
                .font(BlackmagicCamStyle.labelFont(size: 12, weight: .heavy))
                .tracking(1.1)
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(BlackmagicCamStyle.recordRed.opacity(controller.isBulbActive ? 0.24 : 0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(BlackmagicCamStyle.recordRed.opacity(0.58), lineWidth: 1))
            }
            .accessibilityLabel(controller.isBulbActive ? "Stop bulb" : "Shoot")
            .buttonStyle(.plain)

            if controller.isBulbActive {
                Text("\(controller.bulbElapsedSeconds)s")
                    .font(BlackmagicCamStyle.readoutFont(size: 12, weight: .semibold))
                    .foregroundStyle(BlackmagicCamStyle.recordRed)
            }

            Button {
                Task { await controller.disconnect() }
            } label: {
                Image(systemName: "eject")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(BlackmagicCamStyle.amber)
                    .frame(width: 42, height: 38)
                    .blackmagicButtonShell(cornerRadius: 12)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(BlackmagicCamStyle.rail)
        .overlay(Rectangle().fill(Color.white.opacity(0.10)).frame(height: 1), alignment: .bottom)
        // Firmware/update note: header actions call controller APIs only; when firmware changes capability support, gate behavior in controller/snapshot rather than this chrome.
    }

    private var deviceName: String {
        if case .connected(let device) = controller.status {
            return device.name
        }
        return "Camera"
    }
}

enum WorkspaceTab: Hashable {
    case live
    case controls
    case gallery
}

