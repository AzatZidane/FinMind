import SwiftUI

@main
struct FinMindApp: App {
    @StateObject private var app = AppState()

    var body: some Scene {
        WindowGroup {
            AddExpenseView()               // ← или BudgetView(), CalendarListView() и т. п.
                .environmentObject(app)
                .onAppear { app.loadFromDiskIfAvailable() }
        }
    }
}


