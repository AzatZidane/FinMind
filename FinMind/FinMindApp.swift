import SwiftUI

@main
struct FinMindApp: App {
    @StateObject private var appState: AppState

    init() {
        // Твой load() возвращает НЕ-опциональный AppState (и не бросает) — значит без "??"
        let loaded = Persistence.shared.load()
        _appState = StateObject(wrappedValue: loaded)

        // Если когда-нибудь сделаешь load() бросающим:
        // let loaded = (try? Persistence.shared.load()) ?? AppState()
        // _appState = StateObject(wrappedValue: loaded)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .preferredColorScheme(appState.appearance.swiftUIColorScheme) // тема из настроек
                .onAppear { appState.startAutoSave() }
        }
    }
}
