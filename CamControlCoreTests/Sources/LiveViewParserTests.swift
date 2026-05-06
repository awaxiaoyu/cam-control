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

    func testNikonLiveViewBuildsHistogramFromJPEG() throws {
        let jpeg = try XCTUnwrap(Data(base64Encoded: Self.onePixelJPEGBase64))
        var data = Data([9, 8, 7, 6])
        data.append(jpeg)

        let frame = NikonLiveViewParser.parse(data: data, productID: 0xffff)

        XCTAssertEqual(frame?.histogram?.count, 256)
        XCTAssertEqual(frame?.histogram?.contains(where: { $0 > 0 }), true)
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

    private static let onePixelJPEGBase64 = "/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAMCAgMCAgMDAwMEAwMEBQgFBQQEBQoHBwYIDAoMDAsKCwsNDhIQDQ4RDgsLEBYQERMUFRUVDA8XGBYUGBIUFRT/2wBDAQMEBAUEBQkFBQkUDQsNFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBT/wAARCAABAAEDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwD50ooor8MP9Uz/2Q=="
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
