import CoreGraphics
import Foundation

public protocol CameraDriver: AnyObject {
    var vendor: CameraVendor { get }
    var capabilities: CameraCapabilities { get }
    func open(client: PTPClient, info: PTPDeviceInfo, device: CameraDevice) async throws -> CameraSnapshot
    func refreshProperties(client: PTPClient) async throws -> [CameraPropertyState]
    func setProperty(_ key: CameraPropertyKey, value: Int64, client: PTPClient) async throws
    func capture(client: PTPClient) async throws
    func setLiveView(_ enabled: Bool, client: PTPClient) async throws
    func getLiveViewFrame(client: PTPClient) async throws -> LiveViewFrame?
    func focus(client: PTPClient) async throws
    func driveLens(direction: DriveLensDirection, step: DriveLensStep, client: PTPClient) async throws
    func setLiveViewAfArea(x: Double, y: Double, client: PTPClient) async throws
}

public extension CameraDriver {
    func focus(client: PTPClient) async throws {}
    func driveLens(direction: DriveLensDirection, step: DriveLensStep, client: PTPClient) async throws {}
    func setLiveViewAfArea(x: Double, y: Double, client: PTPClient) async throws {}
}

final class PropertyMap {
    private(set) var map: [CameraPropertyKey: UInt16] = [:]
    private(set) var descriptors: [UInt16: DevicePropDesc] = [:]

    func add(_ key: CameraPropertyKey, _ code: UInt16) {
        map[key] = code
    }

    func code(for key: CameraPropertyKey) -> UInt16? {
        map[key]
    }

    func descriptor(for key: CameraPropertyKey) -> DevicePropDesc? {
        guard let code = map[key] else { return nil }
        return descriptors[code]
    }

    func setDescriptor(_ descriptor: DevicePropDesc) {
        descriptors[descriptor.propertyCode] = descriptor
    }

    func states(current: [UInt16: Int64]) -> [CameraPropertyState] {
        CameraPropertyKey.allCases.compactMap { key in
            guard let code = map[key] else { return nil }
            return CameraPropertyState(
                key: key,
                ptpCode: code,
                value: current[code] ?? descriptors[code]?.currentValue ?? 0,
                descriptor: descriptors[code]
            )
        }
    }
}

public final class NikonCameraDriver: CameraDriver {
    public let vendor: CameraVendor = .nikon
    public private(set) var capabilities = CameraCapabilities.empty

    private let properties = PropertyMap()
    private var currentValues: [UInt16: Int64] = [:]
    private var supportedOperations: Set<UInt16> = []
    private var supportedProperties: Set<UInt16> = []
    private var productID: UInt16 = 0
    private var lastFrame: LiveViewFrame?

    public init() {}

    public func open(client: PTPClient, info: PTPDeviceInfo, device: CameraDevice) async throws -> CameraSnapshot {
        productID = device.productID ?? 0
        supportedOperations = Set(info.operationsSupported)
        supportedProperties = Set(info.devicePropertiesSupported)
        capabilities.liveView = supportedOperations.isSuperset(of: [PTP.Operation.nikonGetLiveViewImage, PTP.Operation.nikonStartLiveView, PTP.Operation.nikonEndLiveView])
        capabilities.driveLens = supportedOperations.contains(PTP.Operation.nikonMfDrive)
        capabilities.liveViewAfArea = supportedOperations.contains(PTP.Operation.nikonChangeAfArea)
        capabilities.autofocus = supportedOperations.contains(PTP.Operation.nikonAfDrive)
        capabilities.histogram = false

        try await client.openPTPSession()

        if supportedOperations.contains(PTP.Operation.nikonGetVendorPropCodes) {
            let vendorCodes = try await client.getUInt16Array(operationCode: PTP.Operation.nikonGetVendorPropCodes)
            supportedProperties.formUnion(vendorCodes)
            try? await client.setDevicePropValue(PTP.Property.nikonRecordingMedia, value: 1, dataType: PTP.DataType.uint8)
        }

        buildPropertyMap()
        try await loadDescriptorsAndValues(client: client)
        return CameraSnapshot(deviceInfo: info, capabilities: capabilities, properties: properties.states(current: currentValues), focusPoints: focusPoints(productID: productID))
    }

    public func refreshProperties(client: PTPClient) async throws -> [CameraPropertyState] {
        for descriptor in properties.descriptors.values {
            currentValues[descriptor.propertyCode] = try? await client.getDevicePropValue(descriptor.propertyCode, dataType: descriptor.dataType)
        }
        return properties.states(current: currentValues)
    }

    public func setProperty(_ key: CameraPropertyKey, value: Int64, client: PTPClient) async throws {
        guard let code = properties.code(for: key), let descriptor = properties.descriptor(for: key) else { return }
        try await client.setDevicePropValue(code, value: value, dataType: descriptor.dataType)
        currentValues[code] = value
    }

    public func capture(client: PTPClient) async throws {
        try await client.initiateCapture()
    }

    public func setLiveView(_ enabled: Bool, client: PTPClient) async throws {
        guard capabilities.liveView else { return }
        if enabled {
            try await client.execute(operationCode: PTP.Operation.nikonStartLiveView)
            for _ in 0..<10 {
                try await Task.sleep(nanoseconds: 300_000_000)
                do {
                    try await client.execute(operationCode: PTP.Operation.nikonDeviceReady, retriesOnBusy: 0)
                    return
                } catch PTPClientError.response(let code) where code == PTP.Response.deviceBusy {
                    continue
                }
            }
        } else {
            try await client.execute(operationCode: PTP.Operation.nikonEndLiveView, retriesOnBusy: 6)
        }
    }

    public func getLiveViewFrame(client: PTPClient) async throws -> LiveViewFrame? {
        guard capabilities.liveView else { return nil }
        let response = try await client.execute(operationCode: PTP.Operation.nikonGetLiveViewImage, retriesOnBusy: 8)
        let frame = NikonLiveViewParser.parse(data: response.payload, productID: productID)
        lastFrame = frame
        return frame
    }

    public func focus(client: PTPClient) async throws {
        guard capabilities.autofocus else { return }
        try await client.execute(operationCode: PTP.Operation.nikonAfDrive, retriesOnBusy: 6)
    }

    public func driveLens(direction: DriveLensDirection, step: DriveLensStep, client: PTPClient) async throws {
        guard capabilities.driveLens else { return }
        let directionValue: UInt32 = direction == .far ? 0x02 : 0x01
        try await client.execute(operationCode: PTP.Operation.nikonMfDrive, parameters: [directionValue, UInt32(step.rawValue * 300)])
    }

    public func setLiveViewAfArea(x: Double, y: Double, client: PTPClient) async throws {
        guard capabilities.liveViewAfArea, let frame = lastFrame, let whole = frame.wholeSize, let afSize = frame.autofocusFrameSize else { return }
        let centerX = min(whole.width - afSize.width / 2, max(afSize.width / 2, CGFloat(x) * whole.width))
        let centerY = min(whole.height - afSize.height / 2, max(afSize.height / 2, CGFloat(y) * whole.height))
        try await client.execute(operationCode: PTP.Operation.nikonChangeAfArea, parameters: [UInt32(centerX), UInt32(centerY)])
    }

    private func buildPropertyMap() {
        if supportedProperties.contains(PTP.Property.nikonShutterSpeed) {
            properties.add(.shutterSpeed, PTP.Property.nikonShutterSpeed)
        } else {
            properties.add(.shutterSpeed, PTP.Property.exposureTime)
        }
        properties.add(.aperture, PTP.Property.fNumber)
        properties.add(.iso, PTP.Property.exposureIndex)
        properties.add(.whiteBalance, PTP.Property.whiteBalance)
        properties.add(.colorTemperature, PTP.Property.nikonWbColorTemp)
        properties.add(.shootingMode, PTP.Property.exposureProgramMode)
        properties.add(.batteryLevel, PTP.Property.batteryLevel)
        properties.add(.focusMode, PTP.Property.focusMode)
        properties.add(.pictureStyle, PTP.Property.nikonActivePictureControlItem)
        properties.add(.exposureMeteringMode, PTP.Property.exposureMeteringMode)
        properties.add(.focusMeteringMode, PTP.Property.focusMeteringMode)
        properties.add(.currentFocusPoint, PTP.Property.nikonFocusArea)
        properties.add(.exposureIndicator, PTP.Property.nikonExposureIndicateStatus)
        properties.add(.exposureCompensation, PTP.Property.exposureBiasCompensation)
    }

    private func loadDescriptorsAndValues(client: PTPClient) async throws {
        for code in Set(properties.map.values) where supportedProperties.contains(code) {
            do {
                let descriptor = try await client.getDevicePropDesc(code)
                properties.setDescriptor(descriptor)
                currentValues[code] = try? await client.getDevicePropValue(code, dataType: descriptor.dataType)
            } catch {
                continue
            }
        }
    }
}

public final class CanonCameraDriver: CameraDriver {
    public let vendor: CameraVendor = .canon
    public private(set) var capabilities = CameraCapabilities.empty

    private let properties = PropertyMap()
    private var currentValues: [UInt16: Int64] = [:]
    private var supportedOperations: Set<UInt16> = []
    private var liveViewOpen = false

    public init() {}

    public func open(client: PTPClient, info: PTPDeviceInfo, device: CameraDevice) async throws -> CameraSnapshot {
        supportedOperations = Set(info.operationsSupported)
        capabilities.liveView = supportedOperations.contains(PTP.Operation.eosGetLiveViewPicture)
        capabilities.bulb = supportedOperations.isSuperset(of: [PTP.Operation.eosBulbStart, PTP.Operation.eosBulbEnd])
        capabilities.driveLens = supportedOperations.contains(PTP.Operation.eosDriveLens)
        capabilities.histogram = true

        try await client.openPTPSession()
        try await client.execute(operationCode: PTP.Operation.eosSetPCConnectMode, parameters: [1])
        try await client.execute(operationCode: PTP.Operation.eosSetEventMode, parameters: [1])

        buildPropertyMap()
        try await loadDescriptorsAndValues(client: client)
        return CameraSnapshot(deviceInfo: info, capabilities: capabilities, properties: properties.states(current: currentValues), focusPoints: [])
    }

    public func refreshProperties(client: PTPClient) async throws -> [CameraPropertyState] {
        for descriptor in properties.descriptors.values {
            currentValues[descriptor.propertyCode] = try? await client.getDevicePropValue(descriptor.propertyCode, dataType: descriptor.dataType)
        }
        return properties.states(current: currentValues)
    }

    public func setProperty(_ key: CameraPropertyKey, value: Int64, client: PTPClient) async throws {
        guard let code = properties.code(for: key) else { return }
        var payload = Data()
        payload.appendUInt32LE(0x0c)
        payload.appendUInt32LE(UInt32(code))
        payload.appendUInt32LE(UInt32(truncatingIfNeeded: value))
        try await client.execute(operationCode: PTP.Operation.eosSetDevicePropValue, outData: payload)
        currentValues[code] = value
    }

    public func capture(client: PTPClient) async throws {
        if capabilities.bulb, currentValues[PTP.Property.eosShutterSpeed] == 0x0c {
            try await client.execute(operationCode: PTP.Operation.eosBulbStart)
        } else {
            try await client.execute(operationCode: PTP.Operation.eosTakePicture, retriesOnBusy: 6)
        }
    }

    public func setLiveView(_ enabled: Bool, client: PTPClient) async throws {
        guard capabilities.liveView else { return }
        let modeValue: Int64 = enabled ? 1 : 0
        try await setEOSProperty(code: PTP.Property.eosEvfMode, value: modeValue, client: client)
        let existing = currentValues[PTP.Property.eosEvfOutputDevice] ?? 0
        let pcBit: Int64 = 2
        let output = enabled ? (existing | pcBit) : (existing & ~pcBit)
        try await setEOSProperty(code: PTP.Property.eosEvfOutputDevice, value: output, client: client)
        liveViewOpen = enabled
    }

    public func getLiveViewFrame(client: PTPClient) async throws -> LiveViewFrame? {
        guard liveViewOpen else { return nil }
        let response = try await client.execute(operationCode: PTP.Operation.eosGetLiveViewPicture, parameters: [0x100000], retriesOnBusy: 8)
        return CanonLiveViewParser.parse(data: response.payload)
    }

    public func driveLens(direction: DriveLensDirection, step: DriveLensStep, client: PTPClient) async throws {
        guard capabilities.driveLens, liveViewOpen else { return }
        var value: UInt32 = direction == .near ? 0 : 0x8000
        value |= UInt32(step.rawValue)
        try await client.execute(operationCode: PTP.Operation.eosDriveLens, parameters: [value])
    }

    private func buildPropertyMap() {
        properties.add(.shutterSpeed, PTP.Property.eosShutterSpeed)
        properties.add(.aperture, PTP.Property.eosApertureValue)
        properties.add(.iso, PTP.Property.eosIsoSpeed)
        properties.add(.whiteBalance, PTP.Property.eosWhiteBalance)
        properties.add(.shootingMode, PTP.Property.eosShootingMode)
        properties.add(.availableShots, PTP.Property.eosAvailableShots)
        properties.add(.colorTemperature, PTP.Property.eosColorTemperature)
        properties.add(.focusMode, PTP.Property.eosAfMode)
        properties.add(.pictureStyle, PTP.Property.eosPictureStyle)
        properties.add(.exposureMeteringMode, PTP.Property.eosMeteringMode)
        properties.add(.exposureCompensation, PTP.Property.eosExposureCompensation)
    }

    private func loadDescriptorsAndValues(client: PTPClient) async throws {
        for code in Set(properties.map.values) {
            do {
                let descriptor = try await client.getDevicePropDesc(code)
                properties.setDescriptor(descriptor)
                currentValues[code] = try? await client.getDevicePropValue(code, dataType: descriptor.dataType)
            } catch {
                continue
            }
        }
    }

    private func setEOSProperty(code: UInt16, value: Int64, client: PTPClient) async throws {
        var payload = Data()
        payload.appendUInt32LE(0x0c)
        payload.appendUInt32LE(UInt32(code))
        payload.appendUInt32LE(UInt32(truncatingIfNeeded: value))
        try await client.execute(operationCode: PTP.Operation.eosSetDevicePropValue, outData: payload, retriesOnBusy: 6)
        currentValues[code] = value
    }
}

private func focusPoints(productID: UInt16) -> [FocusPoint] {
    switch productID {
    case PTP.NikonProduct.d40:
        return [
            FocusPoint(id: 0, x: 0.5, y: 0.5, size: 0.04),
            FocusPoint(id: 1, x: 0.30, y: 0.5, size: 0.04),
            FocusPoint(id: 2, x: 0.70, y: 0.5, size: 0.04)
        ]
    case PTP.NikonProduct.d200, PTP.NikonProduct.d80:
        return [
            FocusPoint(id: 0, x: 0.5, y: 0.5, size: 0.04),
            FocusPoint(id: 1, x: 0.5, y: 0.29, size: 0.04),
            FocusPoint(id: 2, x: 0.5, y: 0.71, size: 0.04),
            FocusPoint(id: 3, x: 0.33, y: 0.5, size: 0.04),
            FocusPoint(id: 4, x: 0.67, y: 0.5, size: 0.04),
            FocusPoint(id: 5, x: 0.22, y: 0.5, size: 0.04),
            FocusPoint(id: 6, x: 0.78, y: 0.5, size: 0.04),
            FocusPoint(id: 7, x: 0.33, y: 0.39, size: 0.04),
            FocusPoint(id: 8, x: 0.67, y: 0.39, size: 0.04),
            FocusPoint(id: 9, x: 0.33, y: 0.61, size: 0.04),
            FocusPoint(id: 10, x: 0.67, y: 0.61, size: 0.04)
        ]
    case PTP.NikonProduct.d5000, PTP.NikonProduct.d90:
        return [
            FocusPoint(id: 1, x: 0.5, y: 0.5, size: 0.04),
            FocusPoint(id: 2, x: 0.5, y: 0.3, size: 0.04),
            FocusPoint(id: 3, x: 0.5, y: 0.7, size: 0.04),
            FocusPoint(id: 4, x: 0.33, y: 0.5, size: 0.04),
            FocusPoint(id: 5, x: 0.33, y: 0.35, size: 0.04),
            FocusPoint(id: 6, x: 0.33, y: 0.65, size: 0.04),
            FocusPoint(id: 7, x: 0.22, y: 0.5, size: 0.04),
            FocusPoint(id: 8, x: 0.67, y: 0.5, size: 0.04),
            FocusPoint(id: 9, x: 0.67, y: 0.35, size: 0.04),
            FocusPoint(id: 10, x: 0.67, y: 0.65, size: 0.04),
            FocusPoint(id: 11, x: 0.78, y: 0.5, size: 0.04)
        ]
    case PTP.NikonProduct.d300, PTP.NikonProduct.d300s, PTP.NikonProduct.d3, PTP.NikonProduct.d3s, PTP.NikonProduct.d3x, PTP.NikonProduct.d700:
        return [
            FocusPoint(id: 1, x: 0.5, y: 0.5, size: 0.035),
            FocusPoint(id: 3, x: 0.5, y: 0.36, size: 0.035),
            FocusPoint(id: 5, x: 0.5, y: 0.64, size: 0.035),
            FocusPoint(id: 21, x: 0.65, y: 0.5, size: 0.035),
            FocusPoint(id: 23, x: 0.65, y: 0.4, size: 0.035),
            FocusPoint(id: 25, x: 0.65, y: 0.6, size: 0.035),
            FocusPoint(id: 31, x: 0.75, y: 0.5, size: 0.035),
            FocusPoint(id: 39, x: 0.35, y: 0.5, size: 0.035),
            FocusPoint(id: 41, x: 0.35, y: 0.4, size: 0.035),
            FocusPoint(id: 43, x: 0.35, y: 0.6, size: 0.035),
            FocusPoint(id: 49, x: 0.25, y: 0.5, size: 0.035)
        ]
    case PTP.NikonProduct.d7000:
        return [
            FocusPoint(id: 1, x: 0.5, y: 0.5, size: 0.035),
            FocusPoint(id: 3, x: 0.5, y: 0.32, size: 0.035),
            FocusPoint(id: 5, x: 0.5, y: 0.68, size: 0.035),
            FocusPoint(id: 19, x: 0.68, y: 0.5, size: 0.035),
            FocusPoint(id: 20, x: 0.68, y: 0.4, size: 0.035),
            FocusPoint(id: 21, x: 0.68, y: 0.6, size: 0.035),
            FocusPoint(id: 25, x: 0.80, y: 0.5, size: 0.035),
            FocusPoint(id: 31, x: 0.32, y: 0.5, size: 0.035),
            FocusPoint(id: 32, x: 0.32, y: 0.4, size: 0.035),
            FocusPoint(id: 33, x: 0.32, y: 0.6, size: 0.035),
            FocusPoint(id: 37, x: 0.20, y: 0.5, size: 0.035)
        ]
    default:
        return []
    }
}
