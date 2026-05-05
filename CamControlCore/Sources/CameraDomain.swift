import Foundation

public enum CameraVendor: String, Sendable, Codable {
    case nikon
    case canon
    case unknown
}

public struct CameraDevice: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let vendorID: UInt16?
    public let productID: UInt16?
    public let vendor: CameraVendor

    public init(id: String, name: String, vendorID: UInt16?, productID: UInt16?, vendor: CameraVendor) {
        self.id = id
        self.name = name
        self.vendorID = vendorID
        self.productID = productID
        self.vendor = vendor
    }
}

public enum CameraTransportEvent: Equatable, Sendable {
    case deviceAdded(CameraDevice)
    case deviceRemoved(String)
    case ptpEvent(Data)
    case devicePropertyChanged(UInt16, Int64?)
    case propertyDescChanged(UInt16, [Int64])
    case objectAdded(UInt32, UInt16?)
    case captureComplete
    case cameraBusy
    case cameraCaptureChanged(Bool)
    case bulbExposureTime(Int)
    case disconnected
    case error(String)
}

public protocol CameraTransport: AnyObject, Sendable {
    var events: AsyncStream<CameraTransportEvent> { get }
    func startBrowsing()
    func stopBrowsing()
    func openSession(with device: CameraDevice) async throws
    func closeSession() async
    func send(_ command: PTPCommand, outData: Data?) async throws -> PTPResponse
}

public enum CameraConnectionStatus: Equatable, Sendable {
    case idle
    case browsing
    case connecting(CameraDevice)
    case connected(CameraDevice)
    case failed(String)
}

public enum CameraPropertyKey: Int, CaseIterable, Identifiable, Sendable {
    case shutterSpeed
    case aperture
    case iso
    case whiteBalance
    case colorTemperature
    case shootingMode
    case batteryLevel
    case focusMode
    case pictureStyle
    case exposureMeteringMode
    case focusMeteringMode
    case currentFocusPoint
    case exposureIndicator
    case exposureCompensation
    case availableShots

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .shutterSpeed: return "Shutter"
        case .aperture: return "Aperture"
        case .iso: return "ISO"
        case .whiteBalance: return "WB"
        case .colorTemperature: return "Color temp"
        case .shootingMode: return "Mode"
        case .batteryLevel: return "Battery"
        case .focusMode: return "Focus"
        case .pictureStyle: return "Picture"
        case .exposureMeteringMode: return "Metering"
        case .focusMeteringMode: return "AF meter"
        case .currentFocusPoint: return "AF point"
        case .exposureIndicator: return "Exposure"
        case .exposureCompensation: return "EV"
        case .availableShots: return "Shots"
        }
    }
}

public struct CameraPropertyState: Equatable, Identifiable, Sendable {
    public var id: CameraPropertyKey { key }
    public let key: CameraPropertyKey
    public let ptpCode: UInt16
    public let value: Int64
    public let descriptor: DevicePropDesc?

    public init(key: CameraPropertyKey, ptpCode: UInt16, value: Int64, descriptor: DevicePropDesc?) {
        self.key = key
        self.ptpCode = ptpCode
        self.value = value
        self.descriptor = descriptor
    }
}

public struct CameraCapabilities: Equatable, Sendable {
    public var liveView = false
    public var histogram = false
    public var driveLens = false
    public var autofocus = false
    public var liveViewAfArea = false
    public var bulb = false

    public static let empty = CameraCapabilities()
}

public struct CameraSnapshot: Equatable, Sendable {
    public var deviceInfo: PTPDeviceInfo?
    public var capabilities: CameraCapabilities
    public var properties: [CameraPropertyState]
    public var focusPoints: [FocusPoint]

    public static let empty = CameraSnapshot(deviceInfo: nil, capabilities: .empty, properties: [], focusPoints: [])
}

public struct FocusPoint: Equatable, Identifiable, Sendable {
    public let id: Int
    public let x: Double
    public let y: Double
    public let size: Double

    public init(id: Int, x: Double, y: Double, size: Double) {
        self.id = id
        self.x = x
        self.y = y
        self.size = size
    }
}

public enum DriveLensDirection: Sendable {
    case near
    case far
}

public enum DriveLensStep: Int64, Sendable {
    case soft = 1
    case medium = 2
    case hard = 3
}

public struct GalleryItem: Equatable, Identifiable, Sendable {
    public var id: UInt32 { objectHandle }
    public let objectHandle: UInt32
    public let filename: String
    public let objectFormat: UInt16
    public let compressedSize: UInt32
    public var cachedURL: URL?

    public init(objectHandle: UInt32, filename: String, objectFormat: UInt16, compressedSize: UInt32, cachedURL: URL? = nil) {
        self.objectHandle = objectHandle
        self.filename = filename
        self.objectFormat = objectFormat
        self.compressedSize = compressedSize
        self.cachedURL = cachedURL
    }
}
