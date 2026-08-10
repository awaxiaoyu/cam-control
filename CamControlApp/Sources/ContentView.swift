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

