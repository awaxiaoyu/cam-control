import CamControlCore
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var controller: CameraController
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage("camera.source.kind") private var selectedSourceRaw = CameraSourceKind.tethered.rawValue

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                NavigationStack {
                    if selectedSource == .phone {
                        PhoneCameraWorkspaceView()
                    } else if case .connected = controller.status {
                        CameraWorkspaceView()
                    } else {
                        DeviceListView(source: selectedSourceBinding)
                    }
                }
            } else {
                NavigationSplitView {
                    DeviceListView(source: selectedSourceBinding)
                } detail: {
                    if selectedSource == .phone {
                        PhoneCameraWorkspaceView()
                    } else if case .connected = controller.status {
                        CameraWorkspaceView()
                    } else {
                        EmptyCameraView()
                    }
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
        VStack(spacing: 12) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Connect a Nikon or Canon camera")
                .font(.title3.weight(.semibold))
            Text("Choose Connected camera from the sidebar, or switch to Phone camera.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
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
        .background(selection == .live ? Color.black : Color(.systemGroupedBackground))
    }

    private func workspaceHeader(title: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Button {
                selection = .live
            } label: {
                Label("Camera", systemImage: "video")
            }
            .buttonStyle(.bordered)

            VStack(alignment: .leading, spacing: 2) {
                Label(title, systemImage: systemImage)
                    .font(.headline)
                Text(deviceName + " · " + (controller.snapshot.deviceInfo?.model ?? "Ready"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task { await controller.refreshProperties() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.bordered)

            Button {
                Task { await controller.capture() }
            } label: {
                Image(systemName: controller.isBulbActive ? "stop.circle.fill" : "camera.circle.fill")
            }
            .accessibilityLabel(controller.isBulbActive ? "Stop bulb" : "Shoot")
            .buttonStyle(.borderedProminent)

            if controller.isBulbActive {
                Text("\(controller.bulbElapsedSeconds)s")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Button {
                Task { await controller.disconnect() }
            } label: {
                Image(systemName: "eject")
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(.regularMaterial)
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

