import SwiftUI

// ✅ AFTER — Firebase is NOT touched at launch
@main
struct TodoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(AuthViewModel())
        }
    }
}
