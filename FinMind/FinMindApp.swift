import SwiftUI

@main
struct FinMindApp: App {
    @StateObject private var appState: AppState

    init() {
        let loaded = Persistence.shared.load()
        // Миграция: если ранее была выбрана тема "Как в системе", переключаем на тёмную.
        // (Можно заменить на .light, если хочешь — логика ниже централизована здесь.)
        if loaded.appearance == .system {
            loaded.appearance = .dark
        }
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
