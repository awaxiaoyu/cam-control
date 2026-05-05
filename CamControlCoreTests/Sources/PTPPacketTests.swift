import XCTest
@testable import CamControlCore

final class PTPPacketTests: XCTestCase {
    func testCommandContainerEncoding() {
        let command = PTPCommand(operationCode: PTP.Operation.openSession, transactionID: 1, parameters: [1])
        let data = command.encodeCommandContainer()
        XCTAssertEqual(Array(data), [16, 0, 0, 0, 1, 0, 2, 16, 1, 0, 0, 0, 1, 0, 0, 0])
    }

    func testResponseParsingStripsDataContainer() throws {
        var rawResponse = Data()
        rawResponse.appendUInt32LE(12)
        rawResponse.appendUInt16LE(PTP.ContainerType.response)
        rawResponse.appendUInt16LE(PTP.Response.ok)
        rawResponse.appendUInt32LE(42)

        var payloadContainer = Data()
        payloadContainer.appendUInt32LE(16)
        payloadContainer.appendUInt16LE(PTP.ContainerType.data)
        payloadContainer.appendUInt16LE(PTP.Operation.getDeviceInfo)
        payloadContainer.appendUInt32LE(42)
        payloadContainer.append(contentsOf: [1, 2, 3, 4])

        let response = try PTPResponse.parse(responseData: payloadContainer, ptpResponseData: rawResponse)
        XCTAssertEqual(response.responseCode, PTP.Response.ok)
        XCTAssertEqual(response.transactionID, 42)
        XCTAssertEqual(response.payload, Data([1, 2, 3, 4]))
    }
}
