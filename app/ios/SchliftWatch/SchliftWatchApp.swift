import SwiftUI

@main
struct SchliftWatchApp: App {
    @StateObject private var phoneConnector = PhoneConnector()
    @StateObject private var heartRateStreamer = HeartRateStreamer()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(phoneConnector)
                .environmentObject(heartRateStreamer)
        }
    }
}
