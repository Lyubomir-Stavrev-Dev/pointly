import SwiftUI

@main
struct PointlyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // All windows are managed by AppDelegate; this placeholder satisfies SwiftUI's Scene requirement.
        Settings { EmptyView() }
    }
}
