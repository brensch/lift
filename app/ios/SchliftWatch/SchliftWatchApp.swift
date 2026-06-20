import SwiftUI
import HealthKit
import WatchKit

@main
struct SchliftWatchApp: App {
    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) private var appDelegate
    @StateObject private var phoneConnector = PhoneConnector.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(phoneConnector)
        }
    }
}

/// Receives the launch the iPhone triggers via `HKHealthStore.startWatchApp(toHandle:)`.
/// `startWatchApp` launches this app into the *background* (it then runs via the
/// workout-processing mode), and on watchOS 10+ a workout session may only be started
/// from this sanctioned launch callback — starting it from any other background context
/// fails with "Cannot start workout session while process is in the background". So we
/// start the HK session right here, via the shared PhoneConnector (whose HR samples flow
/// to the phone). We reach it through the singleton because on a cold background launch
/// the SwiftUI @StateObject may not have been created yet.
final class WatchAppDelegate: NSObject, WKApplicationDelegate {
    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        print("SchliftWatch: launched by phone to handle workout configuration")
        PhoneConnector.shared.startCompanionSessionFromLaunch()
    }
}
