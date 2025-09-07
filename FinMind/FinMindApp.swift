import SwiftUI

@main
struct FinMindApp: App {
    @StateObject private var appState: AppState

    init() {
        let loaded = Persistence.shared.load()
        _appState = StateObject(wrappedValue: loaded)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                // тема берётся из настроек пользователя (AppState)
                .preferredColorScheme(appState.appearance.swiftUIColorScheme)
                .onAppear { appState.startAutoSave() }
        }
    }
}
