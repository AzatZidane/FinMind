import SwiftUI

@main
struct FinMindApp: App {
    @StateObject private var app = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .onAppear {
                    app.loadFromDiskIfAvailable()   // этого достаточно
                }
        }
    }
}

