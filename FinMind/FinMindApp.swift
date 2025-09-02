import SwiftUI

@main
struct FinMindApp: App {
    @StateObject private var appState: AppState

    init() {
        // Если Persistence.load() НЕ бросает ошибку (как в твоём проекте):
        let loaded = Persistence.shared.load() ?? AppState()
        _appState = StateObject(wrappedValue: loaded)

        // Если твой load() всё-таки throws, используй вариант ниже и закомментируй 3 строки выше:
        // let loaded = (try? Persistence.shared.load()) ?? AppState()
        // _appState = StateObject(wrappedValue: loaded)
    }

    var body: some Scene {
        WindowGroup {
            RootView() // <-- возвращаем твой корневой экран с вкладками
                .environmentObject(appState)
                .onAppear { appState.startAutoSave() }
        }
    }
}
