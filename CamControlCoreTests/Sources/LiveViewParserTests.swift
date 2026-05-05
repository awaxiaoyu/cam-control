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
}
