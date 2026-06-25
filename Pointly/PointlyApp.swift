import SwiftUI

@main
struct PointlyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // All windows are managed by AppDelegate.
        // EmptyView prevents SwiftUI from rendering any content in this scene.
        Settings { EmptyView() }
    }
}
