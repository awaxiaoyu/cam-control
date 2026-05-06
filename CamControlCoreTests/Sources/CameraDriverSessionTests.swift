import XCTest
@testable import CamControlCore

final class CameraDriverSessionTests: XCTestCase {
    func testNikonOpenSessionRunsVendorPropertySequence() async throws {
        let transport = MockCameraTransport { command, _ in
            switch command.operationCode {
            case PTP.Operation.nikonGetVendorPropCodes:
                var payload = Data()
                payload.appendUInt32LE(0)
                return PTPResponse(responseCode: PTP.Response.ok, transactionID: command.transactionID, parameters: [], payload: payload, rawResponse: Data())
            default:
                return PTPResponse(responseCode: PTP.Response.ok, transactionID: command.transactionID, parameters: [], payload: Data(), rawResponse: Data())
            }
        }
        let client = PTPClient(transport: transport)
        let driver = NikonCameraDriver()
        let device = CameraDevice(id: "nikon", name: "Nikon", vendorID: PTP.Vendor.nikon, productID: PTP.NikonProduct.d7000, vendor: .nikon)

        _ = try await driver.open(client: client, info: nikonInfo(), device: device)

        XCTAssertEqual(transport.sentCommands.map(\.operationCode), [
            PTP.Operation.openSession,
            PTP.Operation.nikonGetVendorPropCodes,
            PTP.Operation.setDevicePropValue
        ])
    }

    func testCanonOpenSessionRunsEOSHandshakeFirst() async throws {
        let transport = MockCameraTransport { command, _ in
            PTPResponse(responseCode: PTP.Response.ok, transactionID: command.transactionID, parameters: [], payload: Data(), rawResponse: Data())
        }
        let client = PTPClient(transport: transport)
        let driver = CanonCameraDriver()
        let device = CameraDevice(id: "canon", name: "Canon", vendorID: PTP.Vendor.canon, productID: nil, vendor: .canon)

        _ = try await driver.open(client: client, info: canonInfo(), device: device)

        XCTAssertEqual(Array(transport.sentCommands.map(\.operationCode).prefix(3)), [
            PTP.Operation.openSession,
            PTP.Operation.eosSetPCConnectMode,
            PTP.Operation.eosSetEventMode
        ])
    }

    func testCanonEndBulbSendsBulbEnd() async throws {
        let transport = MockCameraTransport { command, _ in
            PTPResponse(responseCode: PTP.Response.ok, transactionID: command.transactionID, parameters: [], payload: Data(), rawResponse: Data())
        }
        let client = PTPClient(transport: transport)
        let driver = CanonCameraDriver()
        let device = CameraDevice(id: "canon", name: "Canon", vendorID: PTP.Vendor.canon, productID: nil, vendor: .canon)

        _ = try await driver.open(client: client, info: canonInfo(bulb: true), device: device)
        try await driver.endBulb(client: client)

        XCTAssertTrue(transport.sentCommands.contains { $0.operationCode == PTP.Operation.eosBulbEnd })
    }

    func testNikonStopLiveViewAcceptsAlreadyStoppedResponse() async throws {
        let transport = MockCameraTransport { command, _ in
            if command.operationCode == PTP.Operation.nikonGetVendorPropCodes {
                var payload = Data()
                payload.appendUInt32LE(0)
                return PTPResponse(responseCode: PTP.Response.ok, transactionID: command.transactionID, parameters: [], payload: payload, rawResponse: Data())
            }
            let responseCode = command.operationCode == PTP.Operation.nikonEndLiveView ? PTP.Response.nikonNotLiveView : PTP.Response.ok
            return PTPResponse(responseCode: responseCode, transactionID: command.transactionID, parameters: [], payload: Data(), rawResponse: Data())
        }
        let client = PTPClient(transport: transport)
        let driver = NikonCameraDriver()
        let device = CameraDevice(id: "nikon", name: "Nikon", vendorID: PTP.Vendor.nikon, productID: PTP.NikonProduct.d7000, vendor: .nikon)

        _ = try await driver.open(client: client, info: nikonInfo(liveView: true), device: device)

        try await driver.setLiveView(false, client: client)
        XCTAssertTrue(transport.sentCommands.contains { $0.operationCode == PTP.Operation.nikonEndLiveView })
    }

    func testNikonControlPropertiesCanOverrideReadOnlyDescriptorFlag() async throws {
        let currentValues: [UInt16: Int64] = [
            PTP.Property.fNumber: 560,
            PTP.Property.exposureIndex: 400,
            PTP.Property.exposureProgramMode: 3
        ]
        let transport = MockCameraTransport { command, _ in
            switch command.operationCode {
            case PTP.Operation.nikonGetVendorPropCodes:
                var payload = Data()
                payload.appendUInt32LE(0)
                return PTPResponse(responseCode: PTP.Response.ok, transactionID: command.transactionID, parameters: [], payload: payload, rawResponse: Data())
            case PTP.Operation.getDevicePropDesc:
                let code = UInt16(truncatingIfNeeded: command.parameters[0])
                return PTPResponse(
                    responseCode: PTP.Response.ok,
                    transactionID: command.transactionID,
                    parameters: [],
                    payload: Self.devicePropDescPayload(code: code, current: currentValues[code] ?? 0),
                    rawResponse: Data()
                )
            case PTP.Operation.getDevicePropValue:
                let code = UInt16(truncatingIfNeeded: command.parameters[0])
                return PTPResponse(
                    responseCode: PTP.Response.ok,
                    transactionID: command.transactionID,
                    parameters: [],
                    payload: try! Data.ptpValue(currentValues[code] ?? 0, dataType: PTP.DataType.uint16),
                    rawResponse: Data()
                )
            default:
                return PTPResponse(responseCode: PTP.Response.ok, transactionID: command.transactionID, parameters: [], payload: Data(), rawResponse: Data())
            }
        }
        let client = PTPClient(transport: transport)
        let driver = NikonCameraDriver()
        let device = CameraDevice(id: "nikon", name: "D7500", vendorID: PTP.Vendor.nikon, productID: nil, vendor: .nikon)

        let snapshot = try await driver.open(client: client, info: nikonInfo(properties: Array(currentValues.keys)), device: device)

        XCTAssertEqual(snapshot.properties.first { $0.key == .aperture }?.descriptor?.isSettable, true)
        XCTAssertEqual(snapshot.properties.first { $0.key == .iso }?.descriptor?.isSettable, true)
        XCTAssertEqual(snapshot.properties.first { $0.key == .shootingMode }?.descriptor?.isSettable, false)
    }

    private func nikonInfo(liveView: Bool = false, properties: [UInt16] = []) -> PTPDeviceInfo {
        var operations: [UInt16] = [
            PTP.Operation.openSession,
            PTP.Operation.nikonGetVendorPropCodes,
            PTP.Operation.setDevicePropValue,
            PTP.Operation.nikonGetEvent,
            PTP.Operation.getDevicePropDesc,
            PTP.Operation.getDevicePropValue
        ]
        if liveView {
            operations.append(contentsOf: [
                PTP.Operation.nikonStartLiveView,
                PTP.Operation.nikonEndLiveView,
                PTP.Operation.nikonGetLiveViewImage
            ])
        }
        return PTPDeviceInfo(
            operationsSupported: operations,
            eventsSupported: [],
            devicePropertiesSupported: properties,
            captureFormats: [],
            imageFormats: [PTP.ObjectFormat.exifJpeg],
            manufacturer: "Nikon",
            model: "D7000",
            deviceVersion: "1.0",
            serialNumber: "123"
        )
    }

    nonisolated private static func devicePropDescPayload(code: UInt16, current: Int64) -> Data {
        var data = Data()
        data.appendUInt16LE(code)
        data.appendUInt16LE(PTP.DataType.uint16)
        data.appendUInt8(0)
        data.appendUInt16LE(UInt16(truncatingIfNeeded: current))
        data.appendUInt16LE(UInt16(truncatingIfNeeded: current))
        data.appendUInt8(2)
        data.appendUInt16LE(3)
        data.appendUInt16LE(UInt16(truncatingIfNeeded: current))
        data.appendUInt16LE(UInt16(truncatingIfNeeded: current + 1))
        data.appendUInt16LE(UInt16(truncatingIfNeeded: current + 2))
        return data
    }

    private func canonInfo(bulb: Bool = false) -> PTPDeviceInfo {
        var operations = [
            PTP.Operation.openSession,
            PTP.Operation.eosSetPCConnectMode,
            PTP.Operation.eosSetEventMode,
            PTP.Operation.eosEventCheck,
            PTP.Operation.eosGetLiveViewPicture
        ]
        if bulb {
            operations.append(contentsOf: [PTP.Operation.eosBulbStart, PTP.Operation.eosBulbEnd])
        }
        return PTPDeviceInfo(
            operationsSupported: operations,
            eventsSupported: [],
            devicePropertiesSupported: [],
            captureFormats: [],
            imageFormats: [PTP.ObjectFormat.exifJpeg],
            manufacturer: "Canon",
            model: "EOS",
            deviceVersion: "1.0",
            serialNumber: "123"
        )
    }
}
