import Foundation

public enum PTPClientError: Error, LocalizedError, Sendable {
    case response(UInt16)
    case missingPayload

    public var errorDescription: String? {
        switch self {
        case .response(let code):
            if code == PTP.Response.storeNotAvailable {
                return "No storage card found. Insert a card to browse or save photos."
            }
            if code == PTP.Response.nikonNotLiveView {
                return "Live View is not active."
            }
            return "Camera returned \(PTP.responseName(code))."
        case .missingPayload:
            return "Camera response did not include data."
        }
    }
}

public struct PTPAction: Equatable, Sendable {
    public let operationCode: UInt16
    public let parameters: [UInt32]
    public let outData: Data?
    public let acceptedResponses: Set<UInt16>
    public let retriesOnBusy: Int

    public init(
        operationCode: UInt16,
        parameters: [UInt32] = [],
        outData: Data? = nil,
        acceptedResponses: Set<UInt16> = [PTP.Response.ok],
        retriesOnBusy: Int = 3
    ) {
        self.operationCode = operationCode
        self.parameters = parameters
        self.outData = outData
        self.acceptedResponses = acceptedResponses
        self.retriesOnBusy = retriesOnBusy
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

    public func currentTransactionID() -> UInt32 {
        transactionID > 1 ? transactionID - 1 : 0
    }

    @discardableResult
    public func execute(
        operationCode: UInt16,
        parameters: [UInt32] = [],
        outData: Data? = nil,
        acceptedResponses: Set<UInt16> = [PTP.Response.ok],
        retriesOnBusy: Int = 3
    ) async throws -> PTPResponse {
        var attempts = 0
        while true {
            let command = PTPCommand(operationCode: operationCode, transactionID: nextTransactionID(), parameters: parameters)
            let dataPhase = outData.map { command.encodeDataContainer(payload: $0) }
            let response = try await transport.send(command, outData: dataPhase)
            if response.responseCode == PTP.Response.deviceBusy,
               !acceptedResponses.contains(PTP.Response.deviceBusy),
               attempts < retriesOnBusy {
                attempts += 1
                try await Task.sleep(nanoseconds: 250_000_000)
                continue
            }
            guard response.isOK || acceptedResponses.contains(response.responseCode) else {
                throw PTPClientError.response(response.responseCode)
            }
            return response
        }
    }

    @discardableResult
    public func execute(_ action: PTPAction) async throws -> PTPResponse {
        try await execute(
            operationCode: action.operationCode,
            parameters: action.parameters,
            outData: action.outData,
            acceptedResponses: action.acceptedResponses,
            retriesOnBusy: action.retriesOnBusy
        )
    }

    @discardableResult
    public func runActions(_ actions: [PTPAction]) async throws -> [PTPResponse] {
        var responses: [PTPResponse] = []
        responses.reserveCapacity(actions.count)
        for action in actions {
            responses.append(try await execute(action))
        }
        return responses
    }

    public func checkNikonEvents() async throws -> [CameraTransportEvent] {
        let response = try await execute(
            operationCode: PTP.Operation.nikonGetEvent,
            acceptedResponses: [PTP.Response.ok, PTP.Response.deviceBusy],
            retriesOnBusy: 0
        )
        guard response.responseCode != PTP.Response.deviceBusy else { return [.cameraBusy] }
        return PTPEventParser.parseNikonEvents(response.payload)
    }

    public func checkCanonEvents() async throws -> [CameraTransportEvent] {
        let response = try await execute(
            operationCode: PTP.Operation.eosEventCheck,
            acceptedResponses: [PTP.Response.ok, PTP.Response.deviceBusy],
            retriesOnBusy: 0
        )
        guard response.responseCode != PTP.Response.deviceBusy else { return [.cameraBusy] }
        return PTPEventParser.parseCanonEvents(response.payload)
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
