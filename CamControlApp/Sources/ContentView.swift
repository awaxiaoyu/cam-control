import CamControlCore
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var controller: CameraController

    var body: some View {
        NavigationSplitView {
            DeviceListView()
        } detail: {
            if case .connected = controller.status {
                CameraWorkspaceView()
            } else {
                EmptyCameraView()
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
            Text("Use USB tethering, then pick it from the sidebar.")
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
        VStack(spacing: 0) {
            toolbar
            Picker("View", selection: $selection) {
                Label("Live", systemImage: "viewfinder").tag(WorkspaceTab.live)
                Label("Controls", systemImage: "slider.horizontal.3").tag(WorkspaceTab.controls)
                Label("Gallery", systemImage: "photo.on.rectangle").tag(WorkspaceTab.gallery)
            }
            .pickerStyle(.segmented)
            .padding()

            Group {
                switch selection {
                case .live:
                    LiveViewPanel()
                case .controls:
                    PropertyPanel()
                case .gallery:
                    GalleryView()
                }
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(deviceName)
                    .font(.headline)
                Text(controller.snapshot.deviceInfo?.model ?? "Ready")
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
                Label("Shoot", systemImage: "camera.circle.fill")
            }
            .buttonStyle(.borderedProminent)

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

private enum WorkspaceTab {
    case live
    case controls
    case gallery
}
