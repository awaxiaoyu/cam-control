import Combine
import Foundation

@MainActor
public final class CameraController: ObservableObject {
    @Published public private(set) var devices: [CameraDevice] = []
    @Published public private(set) var status: CameraConnectionStatus = .idle
    @Published public private(set) var snapshot: CameraSnapshot = .empty
    @Published public private(set) var liveViewFrame: LiveViewFrame?
    @Published public private(set) var galleryItems: [GalleryItem] = []
    @Published public private(set) var pictureStreamItems: [GalleryItem] = []
    @Published public private(set) var lastError: String?
    @Published public private(set) var isLiveViewActive = false
    @Published public private(set) var isBulbActive = false
    @Published public private(set) var bulbElapsedSeconds = 0

    private let transport: CameraTransport
    private var eventTask: Task<Void, Never>?
    private var ptpEventTask: Task<Void, Never>?
    private var liveViewTask: Task<Void, Never>?
    private var client: PTPClient?
    private var driver: CameraDriver?
    private var liveViewEmptyFrames = 0
    private var storageWarningShown = false

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
            self.storageWarningShown = false
            self.client = client
            self.driver = driver
            if let index = devices.firstIndex(where: { $0.id == device.id }) {
                devices[index] = resolvedDevice
            }
            self.snapshot = snapshot
            self.status = .connected(resolvedDevice)
            self.lastError = nil
            self.startPTPEventPolling()
            await refreshGallery()
        } catch {
            lastError = error.localizedDescription
            status = .failed(error.localizedDescription)
        }
    }

    public func disconnect() async {
        ptpEventTask?.cancel()
        ptpEventTask = nil
        stopLiveView()
        if let client {
            await client.closePTPSession()
        }
        await transport.closeSession()
        client = nil
        driver = nil
        snapshot = .empty
        galleryItems = []
        pictureStreamItems = []
        liveViewFrame = nil
        liveViewEmptyFrames = 0
        storageWarningShown = false
        isLiveViewActive = false
        isBulbActive = false
        bulbElapsedSeconds = 0
        status = devices.isEmpty ? .idle : .browsing
    }

    public func capture() async {
        guard let client, let driver else { return }
        do {
            if isBulbActive {
                try await driver.endBulb(client: client)
                isBulbActive = false
                bulbElapsedSeconds = 0
                await refreshGallery()
                return
            }
            let previousHandles = Set(galleryItems.map(\.objectHandle))
            let shouldRestartLiveView = isLiveViewActive && driver.vendor == .nikon
            if isLiveViewActive, driver.vendor == .nikon {
                cancelLiveViewLoop()
                try await driver.setLiveView(false, client: client)
                isLiveViewActive = false
            }
            try await driver.capture(client: client)
            if startsBulbCapture(driver: driver) {
                isBulbActive = true
                bulbElapsedSeconds = 0
                return
            }
            await refreshAfterCapture(previousHandles: previousHandles)
            if shouldRestartLiveView {
                await startLiveView()
            }
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
            liveViewEmptyFrames = 0
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
        cancelLiveViewLoop()
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
            let previousItems = Dictionary(uniqueKeysWithValues: galleryItems.map { ($0.objectHandle, $0) })
            var seenHandles = Set<UInt32>()
            var items: [GalleryItem] = []
            for storageID in storageIDs {
                let handles = try await objectHandlesForGallery(storageID: storageID, client: client)
                for handle in handles.suffix(80).reversed() where seenHandles.insert(handle).inserted {
                    guard let info = try? await client.getObjectInfo(handle: handle), isImage(info.objectFormat, filename: info.filename) else { continue }
                    items.append(await galleryItem(for: info, previous: previousItems[handle]))
                }
            }
            if !items.isEmpty || galleryItems.isEmpty {
                galleryItems = items
            }
        } catch PTPClientError.response(let code) where code == PTP.Response.storeNotAvailable {
            galleryItems = []
            if !storageWarningShown {
                storageWarningShown = true
                lastError = PTPClientError.response(code).localizedDescription
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func refreshAfterCapture(previousHandles: Set<UInt32>) async {
        for attempt in 0..<8 {
            try? await Task.sleep(nanoseconds: attempt == 0 ? 700_000_000 : 500_000_000)
            await pollPTPEvents(reportBusy: false)
            await refreshGallery()
            if let item = galleryItems.first(where: { !previousHandles.contains($0.objectHandle) }) {
                addToPictureStream(item)
                return
            }
        }
    }

    private func objectHandlesForGallery(storageID: UInt32, client: PTPClient) async throws -> [UInt32] {
        var handles: [UInt32]
        do {
            handles = try await client.getObjectHandles(storageID: storageID)
        } catch PTPClientError.response(let code) where code == PTP.Response.storeNotAvailable {
            throw PTPClientError.response(code)
        } catch {
            handles = []
        }
        guard handles.isEmpty else { return handles }

        let formats = [
            PTP.ObjectFormat.exifJpeg,
            PTP.ObjectFormat.unknownImageObject,
            PTP.ObjectFormat.tiffEP,
            PTP.ObjectFormat.jfif,
            PTP.ObjectFormat.png,
            PTP.ObjectFormat.tiff,
            PTP.ObjectFormat.eosCRW,
            PTP.ObjectFormat.eosCRW3
        ]
        var seen = Set<UInt32>()
        for format in formats {
            let formatHandles = (try? await client.getObjectHandles(storageID: storageID, objectFormat: format)) ?? []
            for handle in formatHandles where seen.insert(handle).inserted {
                handles.append(handle)
            }
        }
        return handles
    }

    private func galleryItem(for info: PTPObjectInfo, previous: GalleryItem?) async -> GalleryItem {
        var item = GalleryItem(
            objectHandle: info.objectHandle,
            filename: info.filename,
            objectFormat: info.objectFormat,
            compressedSize: info.compressedSize,
            thumbnailURL: previous?.thumbnailURL,
            cachedURL: previous?.cachedURL
        )
        if item.thumbnailURL == nil {
            item.thumbnailURL = await cacheThumbnail(for: info)
        }
        return item
    }

    private func addOrUpdateGalleryObject(handle: UInt32, format: UInt16?) async {
        guard let client else { return }
        do {
            let info = try await client.getObjectInfo(handle: handle)
            guard isImage(info.objectFormat, filename: info.filename) || format.map({ isImage($0) }) == true else { return }
            let previous = galleryItems.first { $0.objectHandle == handle }
            upsertGalleryItem(await galleryItem(for: info, previous: previous))
        } catch {
            guard let format, isImage(format) else { return }
            upsertGalleryItem(GalleryItem(objectHandle: handle, filename: "IMG_\(handle)", objectFormat: format, compressedSize: 0))
        }
    }

    private func upsertGalleryItem(_ item: GalleryItem) {
        galleryItems.removeAll { $0.objectHandle == item.objectHandle }
        galleryItems.insert(item, at: 0)
        addToPictureStream(item)
    }

    private func addToPictureStream(_ item: GalleryItem) {
        pictureStreamItems.removeAll { $0.objectHandle == item.objectHandle }
        pictureStreamItems.insert(item, at: 0)
        if pictureStreamItems.count > 40 {
            pictureStreamItems.removeLast(pictureStreamItems.count - 40)
        }
    }

    private func cacheThumbnail(for info: PTPObjectInfo) async -> URL? {
        guard let client, isThumbnailImage(info.thumbFormat) else { return nil }
        do {
            let data = try await client.getThumb(handle: info.objectHandle)
            guard !data.isEmpty else { return nil }
            let directory = try cacheDirectory(named: "Thumbnails")
            let url = directory.appendingPathComponent("\(info.objectHandle).jpg")
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    @discardableResult
    public func download(_ item: GalleryItem) async -> URL? {
        guard let client else { return nil }
        do {
            let data = try await client.getObject(handle: item.objectHandle)
            let directory = try cacheDirectory(named: "Images")
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
                liveViewEmptyFrames = 0
            } else if isLiveViewActive {
                liveViewEmptyFrames += 1
                if liveViewEmptyFrames == 10 {
                    lastError = "Live View did not return a frame."
                }
            }
        } catch PTPClientError.response(let code) where code == PTP.Response.nikonNotLiveView {
            cancelLiveViewLoop()
            isLiveViewActive = false
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func cancelLiveViewLoop() {
        liveViewTask?.cancel()
        liveViewTask = nil
        liveViewFrame = nil
        liveViewEmptyFrames = 0
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
        case .ptpEvent(let data):
            let parsed = parsePTPEventData(data)
            if parsed.isEmpty {
                await refreshProperties()
                await refreshGallery()
            } else {
                await handle(parsed)
            }
        case .devicePropertyChanged, .propertyDescChanged:
            await refreshAfterDriverEvent(event)
        case .objectAdded(let handle, let format):
            await addOrUpdateGalleryObject(handle: handle, format: format)
        case .captureComplete:
            await refreshGallery()
        case .cameraBusy:
            lastError = "Camera is busy. Please try again in a moment."
        case .cameraCaptureChanged(let capturing):
            if !capturing {
                isBulbActive = false
                bulbElapsedSeconds = 0
            }
            if !capturing {
                await refreshGallery()
            }
        case .bulbExposureTime(let seconds):
            isBulbActive = true
            bulbElapsedSeconds = seconds
        case .disconnected:
            await disconnect()
        case .error(let message):
            lastError = message
        }
    }

    private func handle(_ events: [CameraTransportEvent]) async {
        for event in events {
            await handle(event)
        }
    }

    private func startPTPEventPolling() {
        ptpEventTask?.cancel()
        ptpEventTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.pollPTPEvents()
                try? await Task.sleep(nanoseconds: 900_000_000)
            }
        }
    }

    private func pollPTPEvents(reportBusy: Bool = true) async {
        guard let client, let driver else { return }
        do {
            let polledEvents = try await driver.pollEvents(client: client)
            let events = polledEvents.filter { reportBusy || $0 != .cameraBusy }
            await handle(events)
        } catch PTPClientError.response(let code) where code == PTP.Response.deviceBusy {
            if reportBusy {
                lastError = "Camera is busy. Please try again in a moment."
            }
        } catch {
            if reportBusy {
                lastError = error.localizedDescription
            }
        }
    }

    private func refreshAfterDriverEvent(_ event: CameraTransportEvent) async {
        guard let client, let driver else { return }
        do {
            if let properties = try await driver.handleEvent(event, client: client) {
                snapshot.properties = properties
            } else {
                await refreshProperties()
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func parsePTPEventData(_ data: Data) -> [CameraTransportEvent] {
        let standard = PTPEventParser.parseStandardEventContainer(data)
        if !standard.isEmpty { return standard }
        switch driver?.vendor {
        case .nikon:
            return PTPEventParser.parseNikonEvents(data)
        case .canon:
            return PTPEventParser.parseCanonEvents(data)
        case .unknown, nil:
            return []
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

    private func startsBulbCapture(driver: CameraDriver) -> Bool {
        guard driver.vendor == .canon, snapshot.capabilities.bulb else { return false }
        return snapshot.properties.first { $0.key == .shutterSpeed }?.value == 0x0c
    }

    private func resolveDevice(_ device: CameraDevice, info: PTPDeviceInfo) -> CameraDevice {
        let name = "\(info.manufacturer) \(info.model)"
        let vendor: CameraVendor
        if device.vendor != .unknown {
            vendor = device.vendor
        } else if name.localizedCaseInsensitiveContains("nikon") {
            vendor = .nikon
        } else if looksLikeNikonModel(info.model) || looksLikeNikonModel(device.name) {
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

    private func looksLikeNikonModel(_ model: String) -> Bool {
        let normalized = model.replacingOccurrences(of: " ", with: "").uppercased()
        guard normalized.hasPrefix("D") else { return false }
        return normalized.dropFirst().first?.isNumber == true
    }

    private func cacheDirectory(named name: String) throws -> URL {
        let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("CamControl", isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func isThumbnailImage(_ format: UInt16) -> Bool {
        switch format {
        case PTP.ObjectFormat.exifJpeg, PTP.ObjectFormat.jfif:
            return true
        default:
            return false
        }
    }

    private func isImage(_ format: UInt16, filename: String? = nil) -> Bool {
        if (UInt16(0x3800)...UInt16(0x3810)).contains(format) {
            return true
        }
        switch format {
        case PTP.ObjectFormat.eosCRW, PTP.ObjectFormat.eosCRW3:
            return true
        default:
            guard let filename else { return false }
            let ext = (filename as NSString).pathExtension.lowercased()
            return ["jpg", "jpeg", "nef", "nrw", "raw", "cr2", "cr3", "tif", "tiff", "heif", "heic"].contains(ext)
        }
    }
}
