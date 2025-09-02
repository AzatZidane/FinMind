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
            RootView()
                .environmentObject(appState)
                .preferredColorScheme(appState.appearance.swiftUIColorScheme) // Тема из настроек
                .onAppear { appState.startAutoSave() }
        }
    }
}
