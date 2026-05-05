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

    private func nikonInfo() -> PTPDeviceInfo {
        PTPDeviceInfo(
            operationsSupported: [
                PTP.Operation.openSession,
                PTP.Operation.nikonGetVendorPropCodes,
                PTP.Operation.setDevicePropValue,
                PTP.Operation.nikonGetEvent
            ],
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
