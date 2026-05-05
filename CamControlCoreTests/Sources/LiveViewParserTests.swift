import CoreGraphics
import XCTest
@testable import CamControlCore

final class LiveViewParserTests: XCTestCase {
    func testUnknownNikonLiveViewFallsBackToJPEGScan() {
        let jpeg = Data([0xff, 0xd8, 0xff, 0xe0, 1, 2, 3, 0xff, 0xd9])
        var data = Data([9, 8, 7, 6])
        data.append(jpeg)
        data.append(contentsOf: [5, 4, 3])
        let frame = NikonLiveViewParser.parse(data: data, productID: 0xffff)
        XCTAssertEqual(frame?.jpegData, jpeg)
    }

    func testCanonLiveViewParserReadsChunksHistogramAndZoomRect() {
        let jpeg = Data([0xff, 0xd8, 1, 2, 0xff, 0xd9])
        let histogram = Data(repeating: 7, count: 4096)
        var data = Data()
        data.appendCanonChunk(type: 0x04) { $0.appendUInt32LE(5) }
        data.appendCanonChunk(type: 0x06) {
            $0.appendUInt32LE(10)
            $0.appendUInt32LE(20)
        }
        data.appendCanonChunk(type: 0x05) {
            $0.appendUInt32LE(110)
            $0.appendUInt32LE(220)
        }
        data.appendCanonChunk(type: 0x03) { $0.append(histogram) }
        data.appendCanonChunk(type: 0x01) { $0.append(jpeg) }

        let frame = CanonLiveViewParser.parse(data: data)

        XCTAssertEqual(frame?.jpegData, jpeg)
        XCTAssertEqual(frame?.histogram, histogram)
        XCTAssertEqual(frame?.zoomFactor, 5)
        XCTAssertEqual(frame?.zoomRect, CGRect(x: 10, y: 20, width: 100, height: 200))
    }
}

private extension Data {
    mutating func appendCanonChunk(type: UInt32, body: (inout Data) -> Void) {
        var payload = Data()
        body(&payload)
        appendUInt32LE(UInt32(8 + payload.count))
        appendUInt32LE(type)
        append(payload)
    }
}
