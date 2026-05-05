import Foundation

public enum PTPEventParser {
    public static func parseNikonEvents(_ data: Data) -> [CameraTransportEvent] {
        var reader = PTPDataReader(data)
        guard let count = try? reader.readUInt16LE() else { return [] }
        var events: [CameraTransportEvent] = []
        events.reserveCapacity(Int(count))

        for _ in 0..<Int(count) where reader.remainingCount >= 6 {
            guard let eventCode = try? reader.readUInt16LE(), let parameter = try? reader.readUInt32LE() else {
                break
            }
            switch eventCode {
            case PTP.Event.objectAdded, PTP.Event.nikonObjectAddedInSdram:
                events.append(.objectAdded(parameter, nil))
            case PTP.Event.devicePropChanged:
                events.append(.devicePropertyChanged(UInt16(truncatingIfNeeded: parameter), nil))
            case PTP.Event.captureComplete, PTP.Event.nikonCaptureCompleteRecInSdram:
                events.append(.captureComplete)
            default:
                continue
            }
        }

        return events
    }

    public static func parseCanonEvents(_ data: Data) -> [CameraTransportEvent] {
        var reader = PTPDataReader(data)
        var events: [CameraTransportEvent] = []

        while reader.remainingCount >= 8 {
            guard let eventLength = try? reader.readUInt32LE(), let rawEvent = try? reader.readUInt32LE(), eventLength >= 8 else {
                break
            }
            let payloadLength = Int(eventLength) - 8
            guard payloadLength <= reader.remainingCount else { break }
            let payload = (try? reader.readData(count: payloadLength)) ?? Data()
            events.append(contentsOf: parseCanonEventPayload(event: UInt16(truncatingIfNeeded: rawEvent), payload: payload))
        }

        return events
    }

    public static func parseStandardEventContainer(_ data: Data) -> [CameraTransportEvent] {
        guard data.count >= 12 else { return [] }
        var reader = PTPDataReader(data)
        guard let length = try? reader.readUInt32LE(),
              let type = try? reader.readUInt16LE(),
              let eventCode = try? reader.readUInt16LE(),
              let _ = try? reader.readUInt32LE(),
              Int(length) <= data.count,
              type == PTP.ContainerType.event else {
            return []
        }

        var parameters: [UInt32] = []
        while reader.offset + 4 <= Int(length) {
            guard let parameter = try? reader.readUInt32LE() else { break }
            parameters.append(parameter)
        }

        switch eventCode {
        case PTP.Event.objectAdded, PTP.Event.nikonObjectAddedInSdram:
            guard let handle = parameters.first else { return [] }
            return [.objectAdded(handle, nil)]
        case PTP.Event.devicePropChanged:
            guard let property = parameters.first else { return [] }
            return [.devicePropertyChanged(UInt16(truncatingIfNeeded: property), nil)]
        case PTP.Event.captureComplete, PTP.Event.nikonCaptureCompleteRecInSdram:
            return [.captureComplete]
        case PTP.Event.eosObjectAdded:
            guard let handle = parameters.first else { return [] }
            let format = parameters.count > 2 ? UInt16(truncatingIfNeeded: parameters[2]) : nil
            return [.objectAdded(handle, format)]
        case PTP.Event.eosDevicePropChanged:
            guard let property = parameters.first else { return [] }
            let value = parameters.count > 1 ? Int64(parameters[1]) : nil
            return [.devicePropertyChanged(UInt16(truncatingIfNeeded: property), value)]
        case PTP.Event.eosDevicePropDescChanged:
            guard let property = parameters.first else { return [] }
            return [.propertyDescChanged(UInt16(truncatingIfNeeded: property), [])]
        case PTP.Event.eosCameraStatus:
            return [.cameraCaptureChanged((parameters.first ?? 0) != 0)]
        case PTP.Event.eosBulbExposureTime:
            return [.bulbExposureTime(Int(parameters.first ?? 0))]
        default:
            return []
        }
    }

    private static func parseCanonEventPayload(event: UInt16, payload: Data) -> [CameraTransportEvent] {
        var reader = PTPDataReader(payload)
        switch event {
        case PTP.Event.eosObjectAdded:
            guard let handle = try? reader.readUInt32LE(),
                  let _ = try? reader.readUInt32LE(),
                  let format = try? reader.readUInt16LE() else {
                return []
            }
            return [.objectAdded(handle, format)]
        case PTP.Event.eosDevicePropChanged:
            guard let property = try? reader.readUInt32LE() else { return [] }
            let value = reader.remainingCount >= 4 ? Int64((try? reader.readUInt32LE()) ?? 0) : nil
            return [.devicePropertyChanged(UInt16(truncatingIfNeeded: property), value)]
        case PTP.Event.eosDevicePropDescChanged:
            guard let property = try? reader.readUInt32LE(),
                  let _ = try? reader.readUInt32LE(),
                  let count = try? reader.readUInt32LE() else {
                return []
            }
            var values: [Int64] = []
            values.reserveCapacity(Int(count))
            for _ in 0..<Int(count) where reader.remainingCount >= 4 {
                values.append(Int64((try? reader.readUInt32LE()) ?? 0))
            }
            return [.propertyDescChanged(UInt16(truncatingIfNeeded: property), values)]
        case PTP.Event.eosBulbExposureTime:
            guard let seconds = try? reader.readUInt32LE() else { return [] }
            return [.bulbExposureTime(Int(seconds))]
        case PTP.Event.eosCameraStatus:
            guard let status = try? reader.readUInt32LE() else { return [] }
            return [.cameraCaptureChanged(status != 0)]
        case PTP.Event.eosWillSoonShutdown:
            return []
        default:
            return []
        }
    }
}
