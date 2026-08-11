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

    func testUnknownDModelResolvesAsNikonAndUpdatesDeviceList() async throws {
        let device = CameraDevice(id: "mock", name: "D7500", vendorID: nil, productID: nil, vendor: .unknown)
        let transport = MockCameraTransport { command, _ in
            switch command.operationCode {
            case PTP.Operation.getDeviceInfo:
                return PTPResponse(responseCode: PTP.Response.ok, transactionID: command.transactionID, parameters: [], payload: Self.deviceInfoPayload(manufacturer: "", model: "D7500"), rawResponse: Data())
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

        await controller.connect(to: device)

        XCTAssertEqual(controller.devices.first?.vendor, .nikon)
        guard case .connected(let connected) = controller.status else {
            XCTFail("Expected connected")
            return
        }
        XCTAssertEqual(connected.vendor, .nikon)
    }

    func testStoreNotAvailableWarnsWithoutFailingConnection() async throws {
        let device = CameraDevice(id: "mock", name: "D7500", vendorID: nil, productID: nil, vendor: .unknown)
        let transport = MockCameraTransport { command, _ in
            switch command.operationCode {
            case PTP.Operation.getDeviceInfo:
                return PTPResponse(responseCode: PTP.Response.ok, transactionID: command.transactionID, parameters: [], payload: Self.deviceInfoPayload(manufacturer: "", model: "D7500"), rawResponse: Data())
            case PTP.Operation.getStorageIDs:
                return PTPResponse(responseCode: PTP.Response.storeNotAvailable, transactionID: command.transactionID, parameters: [], payload: Data(), rawResponse: Data())
            default:
                return PTPResponse(responseCode: PTP.Response.ok, transactionID: command.transactionID, parameters: [], payload: Data(), rawResponse: Data())
            }
        }
        let controller = CameraController(transport: transport)
        controller.startBrowsing()
        transport.yield(.deviceAdded(device))
        try? await Task.sleep(nanoseconds: 50_000_000)

        await controller.connect(to: device)

        XCTAssertEqual(controller.lastError, "No storage card found. Insert a card to browse or save photos.")
        XCTAssertTrue(controller.galleryItems.isEmpty)
        guard case .connected = controller.status else {
            XCTFail("Expected connected")
            return
        }
    }

    func testObjectAddedEventCreatesGalleryItem() async throws {
        let device = CameraDevice(id: "mock", name: "D7500", vendorID: nil, productID: nil, vendor: .unknown)
        let handle: UInt32 = 42
        let transport = MockCameraTransport { command, _ in
            switch command.operationCode {
            case PTP.Operation.getDeviceInfo:
                return PTPResponse(responseCode: PTP.Response.ok, transactionID: command.transactionID, parameters: [], payload: Self.deviceInfoPayload(manufacturer: "Nikon", model: "D7500"), rawResponse: Data())
            case PTP.Operation.getStorageIDs:
                var payload = Data()
                payload.appendUInt32LE(0)
                return PTPResponse(responseCode: PTP.Response.ok, transactionID: command.transactionID, parameters: [], payload: payload, rawResponse: Data())
            case PTP.Operation.getObjectInfo:
                return PTPResponse(responseCode: PTP.Response.ok, transactionID: command.transactionID, parameters: [], payload: Self.objectInfoPayload(handle: handle, filename: "DSC_0001.JPG"), rawResponse: Data())
            case PTP.Operation.getThumb:
                return PTPResponse(responseCode: PTP.Response.ok, transactionID: command.transactionID, parameters: [], payload: Data([0xff, 0xd8, 0xff, 0xd9]), rawResponse: Data())
            default:
                return PTPResponse(responseCode: PTP.Response.ok, transactionID: command.transactionID, parameters: [], payload: Data(), rawResponse: Data())
            }
        }
        let controller = CameraController(transport: transport)
        controller.startBrowsing()
        transport.yield(.deviceAdded(device))
        try? await Task.sleep(nanoseconds: 50_000_000)

        await controller.connect(to: device)
        transport.yield(.objectAdded(handle, PTP.ObjectFormat.exifJpeg))
        try? await Task.sleep(nanoseconds: 150_000_000)

        XCTAssertEqual(controller.galleryItems.first?.objectHandle, handle)
        XCTAssertNotNil(controller.galleryItems.first?.thumbnailURL)
    }

    func testObjectAddedEventAddsPictureStreamItem() async throws {
        let device = CameraDevice(id: "mock", name: "D7500", vendorID: nil, productID: nil, vendor: .unknown)
        let handle: UInt32 = 77
        let transport = MockCameraTransport { command, _ in
            switch command.operationCode {
            case PTP.Operation.getDeviceInfo:
                return PTPResponse(responseCode: PTP.Response.ok, transactionID: command.transactionID, parameters: [], payload: Self.deviceInfoPayload(manufacturer: "Nikon", model: "D7500"), rawResponse: Data())
            case PTP.Operation.getStorageIDs:
                var payload = Data()
                payload.appendUInt32LE(0)
                return PTPResponse(responseCode: PTP.Response.ok, transactionID: command.transactionID, parameters: [], payload: payload, rawResponse: Data())
            case PTP.Operation.getObjectInfo:
                return PTPResponse(responseCode: PTP.Response.ok, transactionID: command.transactionID, parameters: [], payload: Self.objectInfoPayload(handle: handle, filename: "DSC_0077.JPG"), rawResponse: Data())
            case PTP.Operation.getThumb:
                return PTPResponse(responseCode: PTP.Response.ok, transactionID: command.transactionID, parameters: [], payload: Data([0xff, 0xd8, 0xff, 0xd9]), rawResponse: Data())
            default:
                return PTPResponse(responseCode: PTP.Response.ok, transactionID: command.transactionID, parameters: [], payload: Data(), rawResponse: Data())
            }
        }
        let controller = CameraController(transport: transport)
        controller.startBrowsing()
        transport.yield(.deviceAdded(device))
        try? await Task.sleep(nanoseconds: 50_000_000)

        await controller.connect(to: device)
        transport.yield(.objectAdded(handle, PTP.ObjectFormat.exifJpeg))
        let didReceivePictureStreamItem = await waitUntil { controller.pictureStreamItems.first?.objectHandle == handle }
        XCTAssertTrue(didReceivePictureStreamItem)

        XCTAssertEqual(controller.pictureStreamItems.first?.objectHandle, handle)
        XCTAssertEqual(controller.pictureStreamItems.first?.filename, "DSC_0077.JPG")
    }

    func testCaptureRefreshAddsNewObjectToPictureStream() async throws {
        final class CaptureState: @unchecked Sendable {
            var didCapture = false
        }

        let device = CameraDevice(id: "mock", name: "D7500", vendorID: PTP.Vendor.nikon, productID: PTP.NikonProduct.d7000, vendor: .nikon)
        let handle: UInt32 = 88
        let state = CaptureState()
        let transport = MockCameraTransport { command, _ in
            switch command.operationCode {
            case PTP.Operation.getDeviceInfo:
                return PTPResponse(responseCode: PTP.Response.ok, transactionID: command.transactionID, parameters: [], payload: Self.deviceInfoPayload(manufacturer: "Nikon", model: "D7500"), rawResponse: Data())
            case PTP.Operation.initiateCapture:
                state.didCapture = true
                return PTPResponse(responseCode: PTP.Response.ok, transactionID: command.transactionID, parameters: [], payload: Data(), rawResponse: Data())
            case PTP.Operation.getStorageIDs:
                var payload = Data()
                payload.appendUInt32LE(1)
                payload.appendUInt32LE(1)
                return PTPResponse(responseCode: PTP.Response.ok, transactionID: command.transactionID, parameters: [], payload: payload, rawResponse: Data())
            case PTP.Operation.getObjectHandles:
                var payload = Data()
                payload.appendUInt32LE(state.didCapture ? 1 : 0)
                if state.didCapture {
                    payload.appendUInt32LE(handle)
                }
                return PTPResponse(responseCode: PTP.Response.ok, transactionID: command.transactionID, parameters: [], payload: payload, rawResponse: Data())
            case PTP.Operation.getObjectInfo:
                return PTPResponse(responseCode: PTP.Response.ok, transactionID: command.transactionID, parameters: [], payload: Self.objectInfoPayload(handle: handle, filename: "DSC_0088.JPG"), rawResponse: Data())
            case PTP.Operation.getThumb:
                return PTPResponse(responseCode: PTP.Response.ok, transactionID: command.transactionID, parameters: [], payload: Data([0xff, 0xd8, 0xff, 0xd9]), rawResponse: Data())
            default:
                return PTPResponse(responseCode: PTP.Response.ok, transactionID: command.transactionID, parameters: [], payload: Data(), rawResponse: Data())
            }
        }
        let controller = CameraController(transport: transport)
        controller.startBrowsing()
        transport.yield(.deviceAdded(device))
        try? await Task.sleep(nanoseconds: 50_000_000)

        await controller.connect(to: device)
        await controller.capture()

        XCTAssertEqual(controller.pictureStreamItems.first?.objectHandle, handle)
    }

    func testNikonLiveViewRestartsAfterCapture() async throws {
        let device = CameraDevice(id: "mock", name: "D7000", vendorID: PTP.Vendor.nikon, productID: PTP.NikonProduct.d7000, vendor: .nikon)
        let transport = MockCameraTransport { command, _ in
            switch command.operationCode {
            case PTP.Operation.getDeviceInfo:
                return PTPResponse(responseCode: PTP.Response.ok, transactionID: command.transactionID, parameters: [], payload: Self.deviceInfoPayload(manufacturer: "Nikon", model: "D7000"), rawResponse: Data())
            case PTP.Operation.getStorageIDs:
                var payload = Data()
                payload.appendUInt32LE(0)
                return PTPResponse(responseCode: PTP.Response.ok, transactionID: command.transactionID, parameters: [], payload: payload, rawResponse: Data())
            case PTP.Operation.nikonGetLiveViewImage:
                return PTPResponse(responseCode: PTP.Response.ok, transactionID: command.transactionID, parameters: [], payload: Data([0xff, 0xd8, 0xff, 0xd9]), rawResponse: Data())
            default:
                return PTPResponse(responseCode: PTP.Response.ok, transactionID: command.transactionID, parameters: [], payload: Data(), rawResponse: Data())
            }
        }
        let controller = CameraController(transport: transport)
        controller.startBrowsing()
        transport.yield(.deviceAdded(device))
        try? await Task.sleep(nanoseconds: 50_000_000)

        await controller.connect(to: device)
        await controller.startLiveView()
        await controller.capture()
        controller.stopLiveView()

        let startCount = transport.sentCommands.filter { $0.operationCode == PTP.Operation.nikonStartLiveView }.count
        XCTAssertGreaterThanOrEqual(startCount, 2)
    }

    func testLiveViewNotActiveResponseHasReadableMessage() {
        XCTAssertEqual(PTP.responseName(PTP.Response.nikonNotLiveView), "NotLiveView")
        XCTAssertEqual(PTPClientError.response(PTP.Response.nikonNotLiveView).localizedDescription, "Live View is not active.")
    }

    private func waitUntil(_ predicate: @escaping () -> Bool) async -> Bool {
        for _ in 0..<80 {
            if predicate() { return true }
            try? await Task.sleep(nanoseconds: 25_000_000)
        }
        return predicate()
        // Firmware/update note: event delivery timing changes with camera firmware / simulator load; wait for observable controller state instead of fixed sleeps.
    }

    nonisolated private static func deviceInfoPayload(manufacturer: String = "Nikon", model: String = "D7000") -> Data {
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
        data.appendPTPString(manufacturer)
        data.appendPTPString(model)
        data.appendPTPString("1.0")
        data.appendPTPString("123")
        return data
    }

    nonisolated private static func objectInfoPayload(handle: UInt32, filename: String) -> Data {
        var data = Data()
        data.appendUInt32LE(0x00000001)
        data.appendUInt16LE(PTP.ObjectFormat.exifJpeg)
        data.appendUInt16LE(0)
        data.appendUInt32LE(12345)
        data.appendUInt16LE(PTP.ObjectFormat.exifJpeg)
        data.appendUInt32LE(256)
        data.appendUInt32LE(160)
        data.appendUInt32LE(120)
        data.appendUInt32LE(4000)
        data.appendUInt32LE(3000)
        data.appendUInt32LE(24)
        data.appendUInt32LE(0)
        data.appendUInt16LE(0)
        data.appendUInt32LE(0)
        data.appendUInt32LE(1)
        data.appendPTPString(filename)
        data.appendPTPString("")
        data.appendPTPString("")
        data.appendPTPString("")
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
