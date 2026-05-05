import XCTest
@testable import CamControlCore

final class PTPClientCommandTests: XCTestCase {
    func testExecuteRetriesDeviceBusyBeforeSuccess() async throws {
        let responses = ResponseQueue([
            PTPResponse(responseCode: PTP.Response.deviceBusy, transactionID: 1, parameters: [], payload: Data(), rawResponse: Data()),
            PTPResponse(responseCode: PTP.Response.ok, transactionID: 2, parameters: [], payload: Data(), rawResponse: Data())
        ])
        let transport = MockCameraTransport { command, _ in
            await responses.next(for: command)
        }
        let client = PTPClient(transport: transport)

        let response = try await client.execute(operationCode: PTP.Operation.openSession, retriesOnBusy: 1)

        XCTAssertEqual(response.responseCode, PTP.Response.ok)
        XCTAssertEqual(transport.sentCommands.count, 2)
        XCTAssertEqual(transport.sentCommands.map(\.transactionID), [1, 2])
    }

    func testExecuteAcceptsConfiguredResponseCode() async throws {
        let transport = MockCameraTransport { command, _ in
            PTPResponse(responseCode: PTP.Response.deviceBusy, transactionID: command.transactionID, parameters: [], payload: Data(), rawResponse: Data())
        }
        let client = PTPClient(transport: transport)

        let response = try await client.execute(
            operationCode: PTP.Operation.eosEventCheck,
            acceptedResponses: [PTP.Response.ok, PTP.Response.deviceBusy],
            retriesOnBusy: 0
        )

        XCTAssertEqual(response.responseCode, PTP.Response.deviceBusy)
        XCTAssertEqual(transport.sentCommands.count, 1)
    }

    func testDataPhaseUsesCommandTransactionID() async throws {
        let recorder = DataPhaseRecorder()
        let transport = MockCameraTransport { command, outData in
            await recorder.record(command: command, outData: outData)
            return PTPResponse(responseCode: PTP.Response.ok, transactionID: command.transactionID, parameters: [], payload: Data(), rawResponse: Data())
        }
        let client = PTPClient(transport: transport)

        try await client.setDevicePropValue(PTP.Property.eosIsoSpeed, value: 400, dataType: PTP.DataType.uint32)

        let records = await recorder.records()
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].commandTransactionID, records[0].dataTransactionID)
    }
}

private actor ResponseQueue {
    private var responses: [PTPResponse]

    init(_ responses: [PTPResponse]) {
        self.responses = responses
    }

    func next(for command: PTPCommand) -> PTPResponse {
        guard !responses.isEmpty else {
            return PTPResponse(responseCode: PTP.Response.ok, transactionID: command.transactionID, parameters: [], payload: Data(), rawResponse: Data())
        }
        return responses.removeFirst()
    }
}

private actor DataPhaseRecorder {
    struct Record: Equatable {
        let commandTransactionID: UInt32
        let dataTransactionID: UInt32
    }

    private var stored: [Record] = []

    func record(command: PTPCommand, outData: Data?) {
        let dataTransactionID = (try? PTPResponse.stripDataContainer(outData ?? Data()).transactionID) ?? 0
        stored.append(Record(commandTransactionID: command.transactionID, dataTransactionID: dataTransactionID))
    }

    func records() -> [Record] {
        stored
    }
}
