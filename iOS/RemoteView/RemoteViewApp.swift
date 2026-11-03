import SwiftUI

@main
struct RemoteViewApp: App {
    @StateObject private var session = RemoteSession()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(session)
                .preferredColorScheme(.dark)
        }
    }
}
