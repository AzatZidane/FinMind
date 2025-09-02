import SwiftUI

@main
struct FinMindApp: App {
    @StateObject private var appState: AppState

    init() {
        let loaded = Persistence.shared.load() ?? AppState()
        _appState = StateObject(wrappedValue: loaded)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .onAppear { appState.startAutoSave() }
        }
    }
}
