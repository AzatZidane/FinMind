import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            BudgetView()
                .tabItem { Label("Бюджет", systemImage: "chart.pie.fill") }

            CalendarListView()
                .tabItem { Label("Календарь", systemImage: "calendar") }

            GoalsListView()
                .tabItem { Label("Цели", systemImage: "target") }

            DebtsListView()
                .tabItem { Label("Долги", systemImage: "creditcard") }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AppState())
}
