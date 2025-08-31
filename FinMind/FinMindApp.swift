import SwiftUI

@main
struct FinMindApp: App {
    @StateObject private var app = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .onAppear {
                    // загружаем сохранённое состояние, если есть
                    app.loadFromDiskIfAvailable()
                    // app.startAutoSave() — не нужно вызывать: оно уже запускается в init() AppState
                }
        }
    }
}
