import Foundation

public final class MockCameraTransport: CameraTransport, @unchecked Sendable {
    public let events: AsyncStream<CameraTransportEvent>
    private let continuation: AsyncStream<CameraTransportEvent>.Continuation
    public var sentCommands: [PTPCommand] = []
    public var handler: @Sendable (PTPCommand, Data?) async throws -> PTPResponse

    public init(handler: @escaping @Sendable (PTPCommand, Data?) async throws -> PTPResponse) {
        var continuation: AsyncStream<CameraTransportEvent>.Continuation!
        self.events = AsyncStream { continuation = $0 }
        self.continuation = continuation
        self.handler = handler
    }

    public func startBrowsing() {}
    public func stopBrowsing() {}
    public func openSession(with device: CameraDevice) async throws {}
    public func closeSession() async {}

    public func send(_ command: PTPCommand, outData: Data?) async throws -> PTPResponse {
        sentCommands.append(command)
        return try await handler(command, outData)
    }

    public func yield(_ event: CameraTransportEvent) {
        continuation.yield(event)
    }
}
