import SwiftUI

@main
struct DNSToolsMenuApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // This is a "dummy" scene. It allows the app to compile and run,
        // but since we never invoke "Cmd+," or the "Settings" menu item (which doesn't exist),
        // this window never appears.
        Settings {
            EmptyView()
        }
    }
}
