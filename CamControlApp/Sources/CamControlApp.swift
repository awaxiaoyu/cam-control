import CamControlCore
import SwiftUI

@main
struct CamControlApp: App {
    @StateObject private var controller = CameraController.live()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(controller)
                .task {
                    controller.startBrowsing()
                }
        }
    }
}
