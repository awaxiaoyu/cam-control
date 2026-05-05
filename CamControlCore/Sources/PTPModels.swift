import CoreGraphics
import Foundation

public struct PTPCommand: Equatable, Sendable {
    public let operationCode: UInt16
    public let transactionID: UInt32
    public let parameters: [UInt32]

    public init(operationCode: UInt16, transactionID: UInt32, parameters: [UInt32] = []) {
        self.operationCode = operationCode
        self.transactionID = transactionID
        self.parameters = parameters
    }

    public func encodeCommandContainer() -> Data {
        encodeContainer(type: PTP.ContainerType.command, payload: Data())
    }

    public func encodeDataContainer(payload: Data) -> Data {
        encodeContainer(type: PTP.ContainerType.data, payload: payload)
    }

    private func encodeContainer(type: UInt16, payload: Data) -> Data {
        var data = Data()
        let parameterBytes = parameters.count * MemoryLayout<UInt32>.size
        let length = UInt32(12 + parameterBytes + payload.count)
        data.appendUInt32LE(length)
        data.appendUInt16LE(type)
        data.appendUInt16LE(operationCode)
        data.appendUInt32LE(transactionID)
        for parameter in parameters {
            data.appendUInt32LE(parameter)
        }
        data.append(payload)
        return data
    }
}

public struct PTPResponse: Equatable, Sendable {
    public let responseCode: UInt16
    public let transactionID: UInt32
    public let parameters: [UInt32]
    public let payload: Data
    public let rawResponse: Data

    public var isOK: Bool {
        responseCode == PTP.Response.ok || responseCode == 0
    }

    public static func parse(responseData: Data?, ptpResponseData: Data?) throws -> PTPResponse {
        let response = ptpResponseData ?? Data()
        let payload = try stripDataContainer(responseData ?? Data()).payload

        guard response.count >= 12 else {
            return PTPResponse(responseCode: PTP.Response.ok, transactionID: 0, parameters: [], payload: payload, rawResponse: response)
        }

        var reader = PTPDataReader(response)
        let length = Int(try reader.readUInt32LE())
        let type = try reader.readUInt16LE()
        let code = try reader.readUInt16LE()
        let transactionID = try reader.readUInt32LE()
        guard length <= response.count, type == PTP.ContainerType.response else {
            throw PTPDataError.invalidContainer
        }
        var parameters: [UInt32] = []
        while reader.offset + 4 <= length {
            parameters.append(try reader.readUInt32LE())
        }
        return PTPResponse(responseCode: code, transactionID: transactionID, parameters: parameters, payload: payload, rawResponse: response)
    }

    public static func stripDataContainer(_ data: Data) throws -> (operation: UInt16?, transactionID: UInt32?, payload: Data) {
        guard data.count >= 12 else {
            return (nil, nil, data)
        }
        var reader = PTPDataReader(data)
        let length = Int(try reader.readUInt32LE())
        let type = try reader.readUInt16LE()
        let code = try reader.readUInt16LE()
        let transactionID = try reader.readUInt32LE()
        guard length <= data.count, type == PTP.ContainerType.data else {
            return (nil, nil, data)
        }
        return (code, transactionID, data.subdata(in: 12..<length))
    }
}

public struct PTPDeviceInfo: Equatable, Sendable {
    public let operationsSupported: [UInt16]
    public let eventsSupported: [UInt16]
    public let devicePropertiesSupported: [UInt16]
    public let captureFormats: [UInt16]
    public let imageFormats: [UInt16]
    public let manufacturer: String
    public let model: String
    public let deviceVersion: String
    public let serialNumber: String

    public static func parse(_ data: Data) throws -> PTPDeviceInfo {
        var reader = PTPDataReader(data)
        try reader.skip(2)
        try reader.skip(4)
        try reader.skip(2)
        _ = try reader.readPTPString()
        try reader.skip(2)
        let operations = try reader.readUInt16Array()
        let events = try reader.readUInt16Array()
        let properties = try reader.readUInt16Array()
        let captureFormats = try reader.readUInt16Array()
        let imageFormats = try reader.readUInt16Array()
        let manufacturer = try reader.readPTPString()
        let model = try reader.readPTPString()
        let version = try reader.readPTPString()
        let serial = try reader.readPTPString()
        return PTPDeviceInfo(
            operationsSupported: operations,
            eventsSupported: events,
            devicePropertiesSupported: properties,
            captureFormats: captureFormats,
            imageFormats: imageFormats,
            manufacturer: manufacturer,
            model: model,
            deviceVersion: version,
            serialNumber: serial
        )
    }
}

public enum DevicePropForm: Equatable, Sendable {
    case none
    case range(minimum: Int64, maximum: Int64, step: Int64)
    case enumeration([Int64])
}

public struct DevicePropDesc: Equatable, Sendable {
    public let propertyCode: UInt16
    public let dataType: UInt16
    public let isSettable: Bool
    public let defaultValue: Int64
    public let currentValue: Int64
    public let form: DevicePropForm

    public var values: [Int64] {
        switch form {
        case .enumeration(let values):
            return values
        case .range(let minimum, let maximum, let step):
            guard step > 0, maximum >= minimum else { return [] }
            var output: [Int64] = []
            var value = minimum
            while value <= maximum {
                output.append(value)
                value += step
            }
            return output
        case .none:
            return []
        }
    }

    public static func parse(_ data: Data) throws -> DevicePropDesc {
        var reader = PTPDataReader(data)
        let propertyCode = try reader.readUInt16LE()
        let dataType = try reader.readUInt16LE()
        let getSet = try reader.readUInt8()
        let defaultValue = try reader.readValue(dataType: dataType)
        let currentValue = try reader.readValue(dataType: dataType)
        let formFlag = reader.remainingCount > 0 ? try reader.readUInt8() : 0
        let form: DevicePropForm
        switch formFlag {
        case 1:
            let minimum = try reader.readValue(dataType: dataType)
            let maximum = try reader.readValue(dataType: dataType)
            let step = try reader.readValue(dataType: dataType)
            form = .range(minimum: minimum, maximum: maximum, step: step)
        case 2:
            let count = Int(try reader.readUInt16LE())
            var values: [Int64] = []
            values.reserveCapacity(count)
            for _ in 0..<count {
                values.append(try reader.readValue(dataType: dataType))
            }
            form = .enumeration(values)
        default:
            form = .none
        }
        return DevicePropDesc(
            propertyCode: propertyCode,
            dataType: dataType,
            isSettable: getSet != 0,
            defaultValue: defaultValue,
            currentValue: currentValue,
            form: form
        )
    }
}

public struct PTPObjectInfo: Equatable, Identifiable, Sendable {
    public var id: UInt32 { objectHandle }
    public let objectHandle: UInt32
    public let storageID: UInt32
    public let objectFormat: UInt16
    public let compressedSize: UInt32
    public let filename: String

    public static func parse(handle: UInt32, data: Data) throws -> PTPObjectInfo {
        var reader = PTPDataReader(data)
        let storageID = try reader.readUInt32LE()
        let format = try reader.readUInt16LE()
        try reader.skip(2)
        let size = try reader.readUInt32LE()
        try reader.skip(2)
        try reader.skip(4)
        try reader.skip(4)
        try reader.skip(4)
        try reader.skip(4)
        try reader.skip(4)
        try reader.skip(4)
        try reader.skip(2)
        try reader.skip(4)
        try reader.skip(4)
        let filename = reader.remainingCount > 0 ? (try reader.readPTPString()) : "IMG_\(handle)"
        return PTPObjectInfo(
            objectHandle: handle,
            storageID: storageID,
            objectFormat: format,
            compressedSize: size,
            filename: filename.isEmpty ? "IMG_\(handle)" : filename
        )
    }
}

public struct LiveViewFrame: Equatable, Sendable {
    public let jpegData: Data
    public let histogram: Data?
    public let autofocusFrame: CGRect?
    public let wholeSize: CGSize?
    public let autofocusFrameSize: CGSize?

    public init(jpegData: Data, histogram: Data? = nil, autofocusFrame: CGRect? = nil, wholeSize: CGSize? = nil, autofocusFrameSize: CGSize? = nil) {
        self.jpegData = jpegData
        self.histogram = histogram
        self.autofocusFrame = autofocusFrame
        self.wholeSize = wholeSize
        self.autofocusFrameSize = autofocusFrameSize
    }
}
