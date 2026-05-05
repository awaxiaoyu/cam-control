import Foundation

public enum PTPClientError: Error, LocalizedError, Sendable {
    case response(UInt16)
    case missingPayload

    public var errorDescription: String? {
        switch self {
        case .response(let code):
            return "Camera returned \(PTP.responseName(code))."
        case .missingPayload:
            return "Camera response did not include data."
        }
    }
}

public actor PTPClient {
    private let transport: CameraTransport
    private var transactionID: UInt32 = 1
    private let sessionID: UInt32 = 1

    public init(transport: CameraTransport) {
        self.transport = transport
    }

    public func nextTransactionID() -> UInt32 {
        defer { transactionID += 1 }
        return transactionID
    }

    @discardableResult
    public func execute(
        operationCode: UInt16,
        parameters: [UInt32] = [],
        outData: Data? = nil,
        retriesOnBusy: Int = 3
    ) async throws -> PTPResponse {
        var attempts = 0
        while true {
            let command = PTPCommand(operationCode: operationCode, transactionID: nextTransactionID(), parameters: parameters)
            let dataPhase = outData.map { command.encodeDataContainer(payload: $0) }
            let response = try await transport.send(command, outData: dataPhase)
            if response.responseCode == PTP.Response.deviceBusy, attempts < retriesOnBusy {
                attempts += 1
                try await Task.sleep(nanoseconds: 250_000_000)
                continue
            }
            guard response.isOK else { throw PTPClientError.response(response.responseCode) }
            return response
        }
    }

    public func getDeviceInfo() async throws -> PTPDeviceInfo {
        let response = try await execute(operationCode: PTP.Operation.getDeviceInfo)
        guard !response.payload.isEmpty else { throw PTPClientError.missingPayload }
        return try PTPDeviceInfo.parse(response.payload)
    }

    public func openPTPSession() async throws {
        do {
            try await execute(operationCode: PTP.Operation.openSession, parameters: [sessionID], retriesOnBusy: 1)
        } catch PTPClientError.response(let code) where code == PTP.Response.sessionAlreadyOpen {
            return
        }
    }

    public func closePTPSession() async {
        try? await execute(operationCode: PTP.Operation.closeSession, retriesOnBusy: 0)
    }

    public func getDevicePropDesc(_ propertyCode: UInt16) async throws -> DevicePropDesc {
        let response = try await execute(operationCode: PTP.Operation.getDevicePropDesc, parameters: [UInt32(propertyCode)])
        return try DevicePropDesc.parse(response.payload)
    }

    public func getDevicePropValue(_ propertyCode: UInt16, dataType: UInt16) async throws -> Int64 {
        let response = try await execute(operationCode: PTP.Operation.getDevicePropValue, parameters: [UInt32(propertyCode)])
        var reader = PTPDataReader(response.payload)
        return try reader.readValue(dataType: dataType)
    }

    public func setDevicePropValue(_ propertyCode: UInt16, value: Int64, dataType: UInt16) async throws {
        let payload = try Data.ptpValue(value, dataType: dataType)
        try await execute(operationCode: PTP.Operation.setDevicePropValue, parameters: [UInt32(propertyCode)], outData: payload)
    }

    public func initiateCapture() async throws {
        try await execute(operationCode: PTP.Operation.initiateCapture)
    }

    public func getUInt16Array(operationCode: UInt16, parameters: [UInt32] = []) async throws -> [UInt16] {
        let response = try await execute(operationCode: operationCode, parameters: parameters)
        var reader = PTPDataReader(response.payload)
        return try reader.readUInt16Array()
    }

    public func getStorageIDs() async throws -> [UInt32] {
        let response = try await execute(operationCode: PTP.Operation.getStorageIDs)
        var reader = PTPDataReader(response.payload)
        let count = Int(try reader.readUInt32LE())
        var values: [UInt32] = []
        values.reserveCapacity(count)
        for _ in 0..<count {
            values.append(try reader.readUInt32LE())
        }
        return values
    }

    public func getObjectHandles(storageID: UInt32, objectFormat: UInt16 = 0, association: UInt32 = 0) async throws -> [UInt32] {
        let response = try await execute(
            operationCode: PTP.Operation.getObjectHandles,
            parameters: [storageID, UInt32(objectFormat), association]
        )
        var reader = PTPDataReader(response.payload)
        let count = Int(try reader.readUInt32LE())
        var handles: [UInt32] = []
        handles.reserveCapacity(count)
        for _ in 0..<count {
            handles.append(try reader.readUInt32LE())
        }
        return handles
    }

    public func getObjectInfo(handle: UInt32) async throws -> PTPObjectInfo {
        let response = try await execute(operationCode: PTP.Operation.getObjectInfo, parameters: [handle])
        return try PTPObjectInfo.parse(handle: handle, data: response.payload)
    }

    public func getObject(handle: UInt32) async throws -> Data {
        let response = try await execute(operationCode: PTP.Operation.getObject, parameters: [handle], retriesOnBusy: 8)
        return response.payload
    }

    public func getThumb(handle: UInt32) async throws -> Data {
        let response = try await execute(operationCode: PTP.Operation.getThumb, parameters: [handle], retriesOnBusy: 8)
        return response.payload
    }
}
