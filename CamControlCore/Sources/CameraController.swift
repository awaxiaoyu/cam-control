import Combine
import Foundation

@MainActor
public final class CameraController: ObservableObject {
    @Published public private(set) var devices: [CameraDevice] = []
    @Published public private(set) var status: CameraConnectionStatus = .idle
    @Published public private(set) var snapshot: CameraSnapshot = .empty
    @Published public private(set) var liveViewFrame: LiveViewFrame?
    @Published public private(set) var galleryItems: [GalleryItem] = []
    @Published public private(set) var lastError: String?
    @Published public private(set) var isLiveViewActive = false

    private let transport: CameraTransport
    private var eventTask: Task<Void, Never>?
    private var liveViewTask: Task<Void, Never>?
    private var client: PTPClient?
    private var driver: CameraDriver?

    public init(transport: CameraTransport) {
        self.transport = transport
    }

    public static func live() -> CameraController {
        CameraController(transport: ImageCaptureCoreTransport())
    }

    public func startBrowsing() {
        if eventTask == nil {
            eventTask = Task { [weak self] in
                guard let self else { return }
                for await event in transport.events {
                    await self.handle(event)
                }
            }
        }
        status = .browsing
        transport.startBrowsing()
    }

    public func stopBrowsing() {
        transport.stopBrowsing()
        if case .browsing = status {
            status = .idle
        }
    }

    public func clearError() {
        lastError = nil
    }

    public func connect(to device: CameraDevice) async {
        do {
            status = .connecting(device)
            try await transport.openSession(with: device)
            let client = PTPClient(transport: transport)
            let info = try await client.getDeviceInfo()
            let resolvedDevice = resolveDevice(device, info: info)
            let driver = makeDriver(for: resolvedDevice)
            let snapshot = try await driver.open(client: client, info: info, device: resolvedDevice)
            self.client = client
            self.driver = driver
            self.snapshot = snapshot
            self.status = .connected(resolvedDevice)
            self.lastError = nil
            await refreshGallery()
        } catch {
            lastError = error.localizedDescription
            status = .failed(error.localizedDescription)
        }
    }

    public func disconnect() async {
        stopLiveView()
        if let client {
            await client.closePTPSession()
        }
        await transport.closeSession()
        client = nil
        driver = nil
        snapshot = .empty
        galleryItems = []
        liveViewFrame = nil
        isLiveViewActive = false
        status = devices.isEmpty ? .idle : .browsing
    }

    public func capture() async {
        guard let client, let driver else { return }
        do {
            if isLiveViewActive, driver.vendor == .nikon {
                try await driver.setLiveView(false, client: client)
                isLiveViewActive = false
            }
            try await driver.capture(client: client)
            try await Task.sleep(nanoseconds: 600_000_000)
            await refreshGallery()
        } catch {
            lastError = error.localizedDescription
        }
    }

    public func refreshProperties() async {
        guard let client, let driver else { return }
        do {
            snapshot.properties = try await driver.refreshProperties(client: client)
        } catch {
            lastError = error.localizedDescription
        }
    }

    public func setProperty(_ key: CameraPropertyKey, value: Int64) async {
        guard let client, let driver else { return }
        do {
            try await driver.setProperty(key, value: value, client: client)
            await refreshProperties()
        } catch {
            lastError = error.localizedDescription
        }
    }

    public func toggleLiveView() async {
        isLiveViewActive ? stopLiveView() : await startLiveView()
    }

    public func startLiveView() async {
        guard let client, let driver, snapshot.capabilities.liveView else { return }
        do {
            try await driver.setLiveView(true, client: client)
            isLiveViewActive = true
            liveViewTask?.cancel()
            liveViewTask = Task { [weak self] in
                while !Task.isCancelled {
                    await self?.pullLiveViewFrame()
                    try? await Task.sleep(nanoseconds: 120_000_000)
                }
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    public func stopLiveView() {
        liveViewTask?.cancel()
        liveViewTask = nil
        Task { [weak self] in
            guard let self else { return }
            guard let client = self.client, let driver = self.driver else { return }
            try? await driver.setLiveView(false, client: client)
            await MainActor.run {
                self.isLiveViewActive = false
                self.liveViewFrame = nil
            }
        }
    }

    public func focus() async {
        guard let client, let driver else { return }
        do {
            try await driver.focus(client: client)
        } catch {
            lastError = error.localizedDescription
        }
    }

    public func driveLens(direction: DriveLensDirection, step: DriveLensStep) async {
        guard let client, let driver else { return }
        do {
            try await driver.driveLens(direction: direction, step: step, client: client)
        } catch {
            lastError = error.localizedDescription
        }
    }

    public func setLiveViewAfArea(x: Double, y: Double) async {
        guard let client, let driver else { return }
        do {
            try await driver.setLiveViewAfArea(x: x, y: y, client: client)
        } catch {
            lastError = error.localizedDescription
        }
    }

    public func refreshGallery() async {
        guard let client else { return }
        do {
            let storageIDs = try await client.getStorageIDs()
            var items: [GalleryItem] = []
            for storageID in storageIDs {
                let handles = try await client.getObjectHandles(storageID: storageID)
                for handle in handles.suffix(80).reversed() {
                    guard let info = try? await client.getObjectInfo(handle: handle), isImage(info.objectFormat) else { continue }
                    items.append(GalleryItem(objectHandle: handle, filename: info.filename, objectFormat: info.objectFormat, compressedSize: info.compressedSize))
                }
            }
            galleryItems = items
        } catch {
            lastError = error.localizedDescription
        }
    }

    @discardableResult
    public func download(_ item: GalleryItem) async -> URL? {
        guard let client else { return nil }
        do {
            let data = try await client.getObject(handle: item.objectHandle)
            let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
                .appendingPathComponent("CamControl", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent(item.filename)
            try data.write(to: url, options: .atomic)
            if let index = galleryItems.firstIndex(where: { $0.objectHandle == item.objectHandle }) {
                galleryItems[index].cachedURL = url
            }
            return url
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    private func pullLiveViewFrame() async {
        guard let client, let driver else { return }
        do {
            if let frame = try await driver.getLiveViewFrame(client: client) {
                liveViewFrame = frame
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func handle(_ event: CameraTransportEvent) async {
        switch event {
        case .deviceAdded(let device):
            if !devices.contains(where: { $0.id == device.id }) {
                devices.append(device)
            }
            if case .idle = status {
                status = .browsing
            }
        case .deviceRemoved(let id):
            devices.removeAll { $0.id == id }
            if case .connected(let device) = status, device.id == id {
                await disconnect()
            }
        case .ptpEvent:
            await refreshProperties()
            await refreshGallery()
        case .disconnected:
            await disconnect()
        case .error(let message):
            lastError = message
        }
    }

    private func makeDriver(for device: CameraDevice) -> CameraDriver {
        switch device.vendor {
        case .nikon:
            return NikonCameraDriver()
        case .canon:
            return CanonCameraDriver()
        case .unknown:
            return NikonCameraDriver()
        }
    }

    private func resolveDevice(_ device: CameraDevice, info: PTPDeviceInfo) -> CameraDevice {
        let name = "\(info.manufacturer) \(info.model)"
        let vendor: CameraVendor
        if device.vendor != .unknown {
            vendor = device.vendor
        } else if name.localizedCaseInsensitiveContains("nikon") {
            vendor = .nikon
        } else if name.localizedCaseInsensitiveContains("canon") || name.localizedCaseInsensitiveContains("eos") {
            vendor = .canon
        } else {
            vendor = .unknown
        }
        let vendorID = device.vendorID ?? (vendor == .nikon ? PTP.Vendor.nikon : (vendor == .canon ? PTP.Vendor.canon : nil))
        let productID = device.productID ?? inferProductID(model: info.model, vendor: vendor)
        return CameraDevice(id: device.id, name: device.name, vendorID: vendorID, productID: productID, vendor: vendor)
    }

    private func inferProductID(model: String, vendor: CameraVendor) -> UInt16? {
        guard vendor == .nikon else { return nil }
        let normalized = model.replacingOccurrences(of: " ", with: "").uppercased()
        if normalized.contains("D7000") { return PTP.NikonProduct.d7000 }
        if normalized.contains("D5100") { return PTP.NikonProduct.d5100 }
        if normalized.contains("D5000") { return PTP.NikonProduct.d5000 }
        if normalized.contains("D300S") { return PTP.NikonProduct.d300s }
        if normalized.contains("D300") { return PTP.NikonProduct.d300 }
        if normalized.contains("D200") { return PTP.NikonProduct.d200 }
        if normalized.contains("D90") { return PTP.NikonProduct.d90 }
        if normalized.contains("D80") { return PTP.NikonProduct.d80 }
        if normalized.contains("D40") { return PTP.NikonProduct.d40 }
        if normalized.contains("D700") { return PTP.NikonProduct.d700 }
        if normalized.contains("D3X") { return PTP.NikonProduct.d3x }
        if normalized.contains("D3S") { return PTP.NikonProduct.d3s }
        if normalized.contains("D3") { return PTP.NikonProduct.d3 }
        return nil
    }

    private func isImage(_ format: UInt16) -> Bool {
        switch format {
        case PTP.ObjectFormat.exifJpeg, PTP.ObjectFormat.tiff, PTP.ObjectFormat.eosCRW, PTP.ObjectFormat.eosCRW3:
            return true
        default:
            return false
        }
    }
}
