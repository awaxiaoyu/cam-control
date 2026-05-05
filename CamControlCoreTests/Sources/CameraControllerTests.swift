import XCTest
@testable import CamControlCore

@MainActor
final class CameraControllerTests: XCTestCase {
    func testControllerConnectsWithMockTransportAndCaptures() async throws {
        let device = CameraDevice(id: "mock", name: "Nikon Mock", vendorID: PTP.Vendor.nikon, productID: PTP.NikonProduct.d7000, vendor: .nikon)
        let transport = MockCameraTransport { command, _ in
            switch command.operationCode {
            case PTP.Operation.getDeviceInfo:
                return PTPResponse(responseCode: PTP.Response.ok, transactionID: command.transactionID, parameters: [], payload: Self.deviceInfoPayload(), rawResponse: Data())
            case PTP.Operation.openSession,
                 PTP.Operation.initiateCapture:
                return PTPResponse(responseCode: PTP.Response.ok, transactionID: command.transactionID, parameters: [], payload: Data(), rawResponse: Data())
            case PTP.Operation.getStorageIDs:
                var payload = Data()
                payload.appendUInt32LE(0)
                return PTPResponse(responseCode: PTP.Response.ok, transactionID: command.transactionID, parameters: [], payload: payload, rawResponse: Data())
            default:
                return PTPResponse(responseCode: PTP.Response.ok, transactionID: command.transactionID, parameters: [], payload: Data(), rawResponse: Data())
            }
        }
        let controller = CameraController(transport: transport)
        controller.startBrowsing()
        transport.yield(.deviceAdded(device))
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(controller.devices, [device])
        await controller.connect(to: device)
        XCTAssertTrue(controller.snapshot.capabilities.liveView)
        await controller.capture()
        XCTAssertTrue(transport.sentCommands.contains { $0.operationCode == PTP.Operation.initiateCapture })
    }

    private static func deviceInfoPayload() -> Data {
        var data = Data()
        data.appendUInt16LE(100)
        data.appendUInt32LE(0)
        data.appendUInt16LE(0)
        data.appendPTPString("")
        data.appendUInt16LE(0)
        data.appendUInt16Array([
            PTP.Operation.getDeviceInfo,
            PTP.Operation.openSession,
            PTP.Operation.initiateCapture,
            PTP.Operation.getStorageIDs,
            PTP.Operation.nikonGetLiveViewImage,
            PTP.Operation.nikonStartLiveView,
            PTP.Operation.nikonEndLiveView
        ])
        data.appendUInt16Array([])
        data.appendUInt16Array([])
        data.appendUInt16Array([])
        data.appendUInt16Array([PTP.ObjectFormat.exifJpeg])
        data.appendPTPString("Nikon")
        data.appendPTPString("D7000")
        data.appendPTPString("1.0")
        data.appendPTPString("123")
        return data
    }
}

private extension Data {
    mutating func appendUInt16Array(_ values: [UInt16]) {
        appendUInt32LE(UInt32(values.count))
        for value in values {
            appendUInt16LE(value)
        }
    }

    mutating func appendPTPString(_ string: String) {
        let scalars = Array(string.utf16) + [0]
        appendUInt8(UInt8(scalars.count))
        for scalar in scalars {
            appendUInt16LE(scalar)
        }
    }
}
