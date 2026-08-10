import XCTest
@testable import CamControlCore

final class CameraSourceKindTests: XCTestCase {
    func testSourceKindOffersConnectedAndPhoneCameraChoices() {
        XCTAssertEqual(CameraSourceKind.allCases, [.tethered, .phone])
        XCTAssertEqual(CameraSourceKind.tethered.title, "Connected camera")
        XCTAssertEqual(CameraSourceKind.phone.title, "Phone camera")
        XCTAssertEqual(CameraSourceKind.tethered.systemImage, "cable.connector")
        XCTAssertEqual(CameraSourceKind.phone.systemImage, "iphone.gen3")
    }
}
