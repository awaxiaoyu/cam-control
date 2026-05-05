import XCTest
@testable import CamControlCore

final class PTPModelParsingTests: XCTestCase {
    func testDeviceInfoParserReadsSupportedCodesAndStrings() throws {
        var data = Data()
        data.appendUInt16LE(100)
        data.appendUInt32LE(0)
        data.appendUInt16LE(0)
        data.appendPTPString("")
        data.appendUInt16LE(0)
        data.appendUInt16Array([PTP.Operation.getDeviceInfo, PTP.Operation.nikonGetLiveViewImage])
        data.appendUInt16Array([PTP.Event.objectAdded])
        data.appendUInt16Array([PTP.Property.exposureIndex])
        data.appendUInt16Array([PTP.ObjectFormat.exifJpeg])
        data.appendUInt16Array([PTP.ObjectFormat.exifJpeg])
        data.appendPTPString("Nikon")
        data.appendPTPString("D7000")
        data.appendPTPString("1.0")
        data.appendPTPString("123")

        let info = try PTPDeviceInfo.parse(data)
        XCTAssertEqual(info.manufacturer, "Nikon")
        XCTAssertEqual(info.model, "D7000")
        XCTAssertTrue(info.operationsSupported.contains(PTP.Operation.nikonGetLiveViewImage))
        XCTAssertTrue(info.devicePropertiesSupported.contains(PTP.Property.exposureIndex))
    }

    func testDevicePropDescParserReadsEnumeration() throws {
        var data = Data()
        data.appendUInt16LE(PTP.Property.exposureIndex)
        data.appendUInt16LE(PTP.DataType.uint16)
        data.appendUInt8(1)
        data.appendUInt16LE(100)
        data.appendUInt16LE(200)
        data.appendUInt8(2)
        data.appendUInt16LE(3)
        data.appendUInt16LE(100)
        data.appendUInt16LE(200)
        data.appendUInt16LE(400)

        let desc = try DevicePropDesc.parse(data)
        XCTAssertEqual(desc.propertyCode, PTP.Property.exposureIndex)
        XCTAssertEqual(desc.currentValue, 200)
        XCTAssertEqual(desc.values, [100, 200, 400])
        XCTAssertTrue(desc.isSettable)
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
