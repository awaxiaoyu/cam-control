import Foundation

#if canImport(ImageCaptureCore)
import CoreGraphics
@preconcurrency import ImageCaptureCore

public final class ImageCaptureCoreTransport: NSObject, CameraTransport, @unchecked Sendable {
    public nonisolated let events: AsyncStream<CameraTransportEvent>

    private let browser = ICDeviceBrowser()
    private var continuation: AsyncStream<CameraTransportEvent>.Continuation?
    private var devices: [String: ICCameraDevice] = [:]
    private var activeCamera: ICCameraDevice?
    private var openContinuation: CheckedContinuation<Void, Error>?
    private var closeContinuation: CheckedContinuation<Void, Never>?

    public override init() {
        var localContinuation: AsyncStream<CameraTransportEvent>.Continuation?
        self.events = AsyncStream { continuation in
            localContinuation = continuation
        }
        self.continuation = localContinuation
        super.init()
        browser.delegate = self
        browser.browsedDeviceTypeMask = ICDeviceTypeMask(rawValue: ICDeviceTypeMask.camera.rawValue | ICDeviceLocationTypeMask.local.rawValue)
    }

    public func startBrowsing() {
        browser.start()
    }

    public func stopBrowsing() {
        browser.stop()
    }

    public func openSession(with device: CameraDevice) async throws {
        guard let camera = devices[device.id] else {
            throw ImageCaptureTransportError.deviceNotFound
        }
        activeCamera = camera
        camera.delegate = self
        camera.ptpEventHandler = { [weak self] eventData in
            self?.continuation?.yield(.ptpEvent(eventData))
        }
        try await withCheckedThrowingContinuation { continuation in
            openContinuation = continuation
            camera.requestOpenSession()
        }
    }

    public func closeSession() async {
        guard let activeCamera else { return }
        await withCheckedContinuation { continuation in
            closeContinuation = continuation
            activeCamera.requestCloseSession()
        }
    }

    public func send(_ command: PTPCommand, outData: Data?) async throws -> PTPResponse {
        guard let activeCamera else {
            throw ImageCaptureTransportError.noOpenCamera
        }
        let commandData = command.encodeCommandContainer()
        return try await withCheckedThrowingContinuation { continuation in
            activeCamera.requestSendPTPCommand(commandData, outData: outData) { responseData, ptpResponseData, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                do {
                    continuation.resume(returning: try PTPResponse.parse(responseData: responseData, ptpResponseData: ptpResponseData))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

public enum ImageCaptureTransportError: Error, LocalizedError {
    case deviceNotFound
    case noOpenCamera

    public var errorDescription: String? {
        switch self {
        case .deviceNotFound: return "Camera is no longer available."
        case .noOpenCamera: return "No camera session is open."
        }
    }
}

extension ImageCaptureCoreTransport: ICDeviceBrowserDelegate {
    public func deviceBrowser(_ browser: ICDeviceBrowser, didAdd device: ICDevice, moreComing: Bool) {
        guard let camera = device as? ICCameraDevice else { return }
        let descriptor = makeDescriptor(camera)
        devices[descriptor.id] = camera
        continuation?.yield(.deviceAdded(descriptor))
    }

    public func deviceBrowser(_ browser: ICDeviceBrowser, didRemove device: ICDevice, moreGoing: Bool) {
        let id = deviceUUID(device)
        devices[id] = nil
        continuation?.yield(.deviceRemoved(id))
    }

    public func deviceBrowser(_ browser: ICDeviceBrowser, deviceDidChangeName device: ICDevice) {
        guard let camera = device as? ICCameraDevice else { return }
        continuation?.yield(.deviceAdded(makeDescriptor(camera)))
    }

    private func makeDescriptor(_ camera: ICCameraDevice) -> CameraDevice {
        let name = camera.name ?? "Camera"
        let vendor = inferVendor(name: name, vendorID: nil)
        return CameraDevice(id: deviceUUID(camera), name: name, vendorID: nil, productID: nil, vendor: vendor)
    }

    private func deviceUUID(_ device: ICDevice) -> String {
        if let uuid = device.uuidString, !uuid.isEmpty {
            return uuid
        }
        return device.name ?? UUID().uuidString
    }

    private func inferVendor(name: String, vendorID: UInt16?) -> CameraVendor {
        if vendorID == PTP.Vendor.nikon || name.localizedCaseInsensitiveContains("nikon") { return .nikon }
        if vendorID == PTP.Vendor.canon || name.localizedCaseInsensitiveContains("canon") || name.localizedCaseInsensitiveContains("eos") { return .canon }
        return .unknown
    }
}

extension ImageCaptureCoreTransport: ICCameraDeviceDelegate {
    public func cameraDevice(_ camera: ICCameraDevice, didAdd items: [ICCameraItem]) {}

    public func cameraDevice(_ camera: ICCameraDevice, didRemove items: [ICCameraItem]) {}

    public func cameraDevice(_ camera: ICCameraDevice, didReceiveThumbnail thumbnail: CGImage?, for item: ICCameraItem, error: Error?) {}

    public func cameraDevice(_ camera: ICCameraDevice, didReceiveMetadata metadata: [AnyHashable: Any]?, for item: ICCameraItem, error: Error?) {}

    public func cameraDevice(_ camera: ICCameraDevice, didRenameItems items: [ICCameraItem]) {}

    public func cameraDeviceDidChangeCapability(_ camera: ICCameraDevice) {}

    public func deviceDidBecomeReady(withCompleteContentCatalog device: ICCameraDevice) {}

    public func cameraDeviceDidRemoveAccessRestriction(_ device: ICDevice) {}

    public func cameraDeviceDidEnableAccessRestriction(_ device: ICDevice) {}

    public func device(_ device: ICDevice, didOpenSessionWithError error: Error?) {
        if let error {
            openContinuation?.resume(throwing: error)
        } else {
            openContinuation?.resume()
        }
        openContinuation = nil
    }

    public func device(_ device: ICDevice, didCloseSessionWithError error: Error?) {
        closeContinuation?.resume()
        closeContinuation = nil
    }

    public func didRemove(_ device: ICDevice) {
        continuation?.yield(.disconnected)
    }

    public func device(_ device: ICDevice, didEncounterError error: Error?) {
        continuation?.yield(.error(error?.localizedDescription ?? "Camera error"))
    }

    public func cameraDevice(_ camera: ICCameraDevice, didReceivePTPEvent eventData: Data) {
        continuation?.yield(.ptpEvent(eventData))
    }
}
#else
public final class ImageCaptureCoreTransport: CameraTransport, @unchecked Sendable {
    public let events: AsyncStream<CameraTransportEvent> = AsyncStream { _ in }
    public init() {}
    public func startBrowsing() {}
    public func stopBrowsing() {}
    public func openSession(with device: CameraDevice) async throws { throw ImageCaptureTransportError.unavailable }
    public func closeSession() async {}
    public func send(_ command: PTPCommand, outData: Data?) async throws -> PTPResponse { throw ImageCaptureTransportError.unavailable }
}

public enum ImageCaptureTransportError: Error, LocalizedError {
    case unavailable
    public var errorDescription: String? { "ImageCaptureCore is not available on this platform." }
}
#endif
