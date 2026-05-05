import XCTest
@testable import CamControlCore

final class PTPEventParserTests: XCTestCase {
    func testNikonEventParserMapsObjectPropertyAndCaptureEvents() {
        var data = Data()
        data.appendUInt16LE(3)
        data.appendUInt16LE(PTP.Event.objectAdded)
        data.appendUInt32LE(0x12345678)
        data.appendUInt16LE(PTP.Event.devicePropChanged)
        data.appendUInt32LE(UInt32(PTP.Property.exposureIndex))
        data.appendUInt16LE(PTP.Event.captureComplete)
        data.appendUInt32LE(0)

        let events = PTPEventParser.parseNikonEvents(data)

        XCTAssertEqual(events, [
            .objectAdded(0x12345678, nil),
            .devicePropertyChanged(PTP.Property.exposureIndex, nil),
            .captureComplete
        ])
    }

    func testCanonEventParserMapsObjectPropertiesDescriptorsAndCaptureState() {
        var data = Data()
        data.appendCanonEvent(PTP.Event.eosObjectAdded) {
            $0.appendUInt32LE(0x1020)
            $0.appendUInt32LE(0x00010001)
            $0.appendUInt16LE(PTP.ObjectFormat.exifJpeg)
        }
        data.appendCanonEvent(PTP.Event.eosDevicePropChanged) {
            $0.appendUInt32LE(UInt32(PTP.Property.eosIsoSpeed))
            $0.appendUInt32LE(400)
        }
        data.appendCanonEvent(PTP.Event.eosDevicePropDescChanged) {
            $0.appendUInt32LE(UInt32(PTP.Property.eosApertureValue))
            $0.appendUInt32LE(UInt32(PTP.DataType.uint32))
            $0.appendUInt32LE(2)
            $0.appendUInt32LE(0x28)
            $0.appendUInt32LE(0x30)
        }
        data.appendCanonEvent(PTP.Event.eosCameraStatus) {
            $0.appendUInt32LE(1)
        }
        data.appendCanonEvent(PTP.Event.eosBulbExposureTime) {
            $0.appendUInt32LE(7)
        }

        let events = PTPEventParser.parseCanonEvents(data)

        XCTAssertEqual(events, [
            .objectAdded(0x1020, PTP.ObjectFormat.exifJpeg),
            .devicePropertyChanged(PTP.Property.eosIsoSpeed, 400),
            .propertyDescChanged(PTP.Property.eosApertureValue, [0x28, 0x30]),
            .cameraCaptureChanged(true),
            .bulbExposureTime(7)
        ])
    }

    func testStandardPTPEventContainerParsesObjectAdded() {
        var data = Data()
        data.appendUInt32LE(16)
        data.appendUInt16LE(PTP.ContainerType.event)
        data.appendUInt16LE(PTP.Event.objectAdded)
        data.appendUInt32LE(22)
        data.appendUInt32LE(0x40)

        XCTAssertEqual(PTPEventParser.parseStandardEventContainer(data), [.objectAdded(0x40, nil)])
    }
}

private extension Data {
    mutating func appendCanonEvent(_ event: UInt16, body: (inout Data) -> Void) {
        var payload = Data()
        body(&payload)
        appendUInt32LE(UInt32(8 + payload.count))
        appendUInt32LE(UInt32(event))
        append(payload)
    }
}
