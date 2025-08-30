import SwiftUI

@main
struct FinMindApp: App {
    @StateObject private var appState: AppState = {
        let loaded = Persistence.shared.load()
        loaded.startAutoSave()
        return loaded
    }()
    
    var body: some View {
        ContentView()
            .environmentObject(appState)
    }
}
