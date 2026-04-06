import SwiftUI

@main
struct SchliftWatchApp: App {
    @StateObject private var phoneConnector = PhoneConnector()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(phoneConnector)
        }
    }
}
