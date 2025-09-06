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
                .preferredColorScheme(appState.appearance.swiftUIColorScheme) // тема из настроек
                .onAppear { appState.startAutoSave() }
        }
    }
}
