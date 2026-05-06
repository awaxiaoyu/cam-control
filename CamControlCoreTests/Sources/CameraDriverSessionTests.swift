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

    private func nikonInfo(liveView: Bool = false) -> PTPDeviceInfo {
        var operations: [UInt16] = [
            PTP.Operation.openSession,
            PTP.Operation.nikonGetVendorPropCodes,
            PTP.Operation.setDevicePropValue,
            PTP.Operation.nikonGetEvent
        ]
        if liveView {
            operations.append(contentsOf: [
                PTP.Operation.nikonStartLiveView,
                PTP.Operation.nikonEndLiveView,
                PTP.Operation.nikonGetLiveViewImage
            ])
        }
        PTPDeviceInfo(
            operationsSupported: operations,
            eventsSupported: [],
            devicePropertiesSupported: [],
            captureFormats: [],
            imageFormats: [PTP.ObjectFormat.exifJpeg],
            manufacturer: "Nikon",
            model: "D7000",
            deviceVersion: "1.0",
            serialNumber: "123"
        )
    }

    private func canonInfo() -> PTPDeviceInfo {
        PTPDeviceInfo(
            operationsSupported: [
                PTP.Operation.openSession,
                PTP.Operation.eosSetPCConnectMode,
                PTP.Operation.eosSetEventMode,
                PTP.Operation.eosEventCheck,
                PTP.Operation.eosGetLiveViewPicture
            ],
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
