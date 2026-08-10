import CamControlCore
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var controller: CameraController
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage("camera.source.kind") private var selectedSourceRaw = CameraSourceKind.phone.rawValue
    @State private var normalizedLaunchSource = false

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
            if !normalizedLaunchSource {
                normalizedLaunchSource = true
                if selectedSourceRaw == CameraSourceKind.tethered.rawValue {
                    selectedSourceRaw = CameraSourceKind.phone.rawValue
                    return
                }
            }
            applySourceSelection(selectedSource)
        }
        .onChange(of: selectedSourceRaw) { _, newValue in
            applySourceSelection(CameraSourceKind(rawValue: newValue) ?? .phone)
        }
    }

    private var selectedSource: CameraSourceKind {
        CameraSourceKind(rawValue: selectedSourceRaw) ?? .phone
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
                VStack(spacing: 8) {
                    Text("BLACKMAGIC CAMERA")
                        .font(BlackmagicCamStyle.labelFont(size: 12, weight: .heavy))
                        .tracking(2.1)
                        .foregroundStyle(BlackmagicCamStyle.cyan)
                    Text("Blackmagic Camera")
                        .font(BlackmagicCamStyle.labelFont(size: 38, weight: .heavy))
                        .foregroundStyle(.white)
                }
                BMEmptyState(
                    systemImage: "camera.viewfinder",
                    title: "No camera session open",
                    subtitle: "Open the camera HUD, then switch to Media, Chat, Settings, or Slate from the right-side Blackmagic controls."
                )
                HStack(spacing: 12) {
                    BMStatusPill(title: "Source", value: "PHONE / USB")
                    BMStatusPill(title: "Record", value: "STBY", color: BlackmagicCamStyle.amber)
                    BMStatusPill(title: "Version", value: "3.2.00", color: BlackmagicCamStyle.cyan)
                }
            }
            .padding(24)
            .frame(maxWidth: 760)
        }
        // Firmware/update note: entry copy is reverse-derived from Blackmagic Camera permission/launch strings; update CameraSourceKind/CameraVendor when new camera families are supported.
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
                PropertyPanel()
            case .gallery:
                GalleryView()
            case .chat:
                CloudChatPanel()
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


}

enum WorkspaceTab: Hashable {
    case live
    case controls
    case gallery
    case chat
}

