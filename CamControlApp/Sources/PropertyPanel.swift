import CamControlCore
import SwiftUI

struct PropertyPanel: View {
    @EnvironmentObject private var controller: CameraController

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                ForEach(controller.snapshot.properties) { property in
                    PropertyControl(property: property) { value in
                        Task { await controller.setProperty(property.key, value: value) }
                    }
                }
            }
            .padding()
        }
        .refreshable {
            await controller.refreshProperties()
        }
    }
}

private struct PropertyControl: View {
    let property: CameraPropertyState
    let onChange: (Int64) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(property.key.title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(displayValue(property.value))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if let values = property.descriptor?.values, !values.isEmpty, property.descriptor?.isSettable == true {
                Picker(property.key.title, selection: Binding(
                    get: { property.value },
                    set: { onChange($0) }
                )) {
                    ForEach(values, id: \.self) { value in
                        Text(displayValue(value)).tag(value)
                    }
                }
                .pickerStyle(.menu)
            } else {
                Text(property.descriptor?.isSettable == true ? "Editable on camera" : "Read only")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func displayValue(_ value: Int64) -> String {
        switch property.key {
        case .batteryLevel:
            return "\(value)%"
        case .colorTemperature:
            return "\(value)K"
        default:
            return "0x\(String(UInt64(bitPattern: value), radix: 16))"
        }
    }
}
