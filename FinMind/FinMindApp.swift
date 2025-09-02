import SwiftUI

@main
struct FinMindApp: App {
    @StateObject private var appState: AppState

    init() {
        // Пытаемся загрузить сохранённое состояние; если нет — создаём дефолтное
        let loaded = (try? Persistence.shared.load()) ?? AppState()
        _appState = StateObject(wrappedValue: loaded)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .onAppear {
                    appState.startAutoSave()
                }
        }
    }
}
