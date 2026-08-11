import XCTest

final class CamControlLaunchUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunchStaysForeground() throws {
        let app = XCUIApplication()
        app.launchArguments.append("--launch-smoke-test")
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5), "CamControl should reach foreground on first launch")
        sleep(2)
        XCTAssertEqual(app.state, .runningForeground, "CamControl should not crash back to SpringBoard after launch")
        // Firmware/update note: keep this launch smoke test when Blackmagic UI changes so CI catches first-frame crashes that unit tests cannot see.
    }
}
