import SwiftUI

@main
struct Web_MirrorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView() // No settings window for now
            .hidden()
        }
    }
}
