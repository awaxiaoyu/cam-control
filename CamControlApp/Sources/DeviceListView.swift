import CamControlCore
import SwiftUI

struct DeviceListView: View {
    @EnvironmentObject private var controller: CameraController
    @Binding var source: CameraSourceKind

    var body: some View {
        List {
            Section("Source") {
                Picker("Camera source", selection: $source) {
                    ForEach(CameraSourceKind.allCases) { source in
                        Label(source.title, systemImage: source.systemImage)
                            .tag(source)
                    }
                }
                .pickerStyle(.inline)
            }

            if source == .tethered {
                Section("Cameras") {
                    if controller.devices.isEmpty {
                        Label("No camera", systemImage: "usb")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(controller.devices) { device in
                            Button {
                                Task { await controller.connect(to: device) }
                            } label: {
                                HStack {
                                    Image(systemName: icon(for: device.vendor))
                                    VStack(alignment: .leading) {
                                        Text(device.name)
                                        Text(device.vendor.rawValue.capitalized)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                Section("Phone Camera") {
                    Label("Built-in camera selected", systemImage: "iphone.gen3")
                    Text(CameraSourceKind.phone.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Status") {
                Text(statusText)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("CamControl")
        .toolbar {
            Button {
                controller.startBrowsing()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
        }
    }

    private var statusText: String {
        if source == .phone {
            return "Using phone camera"
        }
        switch controller.status {
        case .idle: return "Idle"
        case .browsing: return "Browsing"
        case .connecting(let device): return "Connecting \(device.name)"
        case .connected(let device): return "Connected \(device.name)"
        case .failed(let message): return message
        }
    }

    private func icon(for vendor: CameraVendor) -> String {
        switch vendor {
        case .nikon: return "n.circle"
        case .canon: return "c.circle"
        case .unknown: return "camera"
        }
    }
}
