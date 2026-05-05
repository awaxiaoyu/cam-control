import Foundation

public enum PTPDataError: Error, LocalizedError, Equatable {
    case outOfBounds
    case unsupportedDataType(UInt16)
    case invalidContainer

    public var errorDescription: String? {
        switch self {
        case .outOfBounds:
            return "PTP data ended unexpectedly."
        case .unsupportedDataType(let type):
            return "Unsupported PTP data type 0x\(String(type, radix: 16))."
        case .invalidContainer:
            return "Invalid PTP container."
        }
    }
}

public struct PTPDataReader: Sendable {
    public let data: Data
    public private(set) var offset: Int = 0

    public init(_ data: Data) {
        self.data = data
    }

    public var remainingCount: Int {
        data.count - offset
    }

    public mutating func readUInt8() throws -> UInt8 {
        guard offset + 1 <= data.count else { throw PTPDataError.outOfBounds }
        defer { offset += 1 }
        return data[offset]
    }

    public mutating func readUInt16LE() throws -> UInt16 {
        let bytes = try readBytes(count: 2)
        return UInt16(bytes[0]) | UInt16(bytes[1]) << 8
    }

    public mutating func readInt16LE() throws -> Int16 {
        Int16(bitPattern: try readUInt16LE())
    }

    public mutating func readUInt32LE() throws -> UInt32 {
        let bytes = try readBytes(count: 4)
        return UInt32(bytes[0]) | UInt32(bytes[1]) << 8 | UInt32(bytes[2]) << 16 | UInt32(bytes[3]) << 24
    }

    public mutating func readInt32LE() throws -> Int32 {
        Int32(bitPattern: try readUInt32LE())
    }

    public mutating func readBytes(count: Int) throws -> [UInt8] {
        guard count >= 0, offset + count <= data.count else { throw PTPDataError.outOfBounds }
        let range = offset ..< offset + count
        offset += count
        return Array(data[range])
    }

    public mutating func readData(count: Int) throws -> Data {
        guard count >= 0, offset + count <= data.count else { throw PTPDataError.outOfBounds }
        let range = offset ..< offset + count
        offset += count
        return data.subdata(in: range)
    }

    public mutating func skip(_ count: Int) throws {
        _ = try readData(count: count)
    }

    public mutating func readUInt16Array() throws -> [UInt16] {
        let count = Int(try readUInt32LE())
        var values: [UInt16] = []
        values.reserveCapacity(count)
        for _ in 0..<count {
            values.append(try readUInt16LE())
        }
        return values
    }

    public mutating func readPTPString() throws -> String {
        let units = Int(try readUInt8())
        guard units > 0 else { return "" }
        let bytes = try readData(count: units * 2)
        var scalars: [UInt16] = []
        var index = bytes.startIndex
        while index < bytes.endIndex {
            let low = UInt16(bytes[index])
            let highIndex = bytes.index(after: index)
            let high = highIndex < bytes.endIndex ? UInt16(bytes[highIndex]) : 0
            let value = low | high << 8
            if value != 0 {
                scalars.append(value)
            }
            index = bytes.index(index, offsetBy: 2)
        }
        return String(decoding: scalars, as: UTF16.self)
    }

    public mutating func readValue(dataType: UInt16) throws -> Int64 {
        switch dataType {
        case PTP.DataType.int8:
            return Int64(Int8(bitPattern: try readUInt8()))
        case PTP.DataType.uint8:
            return Int64(try readUInt8())
        case PTP.DataType.int16:
            return Int64(try readInt16LE())
        case PTP.DataType.uint16:
            return Int64(try readUInt16LE())
        case PTP.DataType.int32:
            return Int64(try readInt32LE())
        case PTP.DataType.uint32:
            return Int64(try readUInt32LE())
        default:
            throw PTPDataError.unsupportedDataType(dataType)
        }
    }
}

public extension Data {
    mutating func appendUInt8(_ value: UInt8) {
        append(value)
    }

    mutating func appendUInt16LE(_ value: UInt16) {
        append(UInt8(value & 0xff))
        append(UInt8((value >> 8) & 0xff))
    }

    mutating func appendInt16LE(_ value: Int16) {
        appendUInt16LE(UInt16(bitPattern: value))
    }

    mutating func appendUInt32LE(_ value: UInt32) {
        append(UInt8(value & 0xff))
        append(UInt8((value >> 8) & 0xff))
        append(UInt8((value >> 16) & 0xff))
        append(UInt8((value >> 24) & 0xff))
    }

    mutating func appendInt32LE(_ value: Int32) {
        appendUInt32LE(UInt32(bitPattern: value))
    }

    static func ptpValue(_ value: Int64, dataType: UInt16) throws -> Data {
        var data = Data()
        switch dataType {
        case PTP.DataType.int8, PTP.DataType.uint8:
            data.appendUInt8(UInt8(truncatingIfNeeded: value))
        case PTP.DataType.int16:
            data.appendInt16LE(Int16(truncatingIfNeeded: value))
        case PTP.DataType.uint16:
            data.appendUInt16LE(UInt16(truncatingIfNeeded: value))
        case PTP.DataType.int32:
            data.appendInt32LE(Int32(truncatingIfNeeded: value))
        case PTP.DataType.uint32:
            data.appendUInt32LE(UInt32(truncatingIfNeeded: value))
        default:
            throw PTPDataError.unsupportedDataType(dataType)
        }
        return data
    }
}
