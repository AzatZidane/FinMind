import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            BudgetView()
                .tabItem {
                    Label("Бюджет", systemImage: "chart.pie.fill")
                }

            CalendarListView()
                .tabItem {
                    Label("Календарь", systemImage: "calendar")
                }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AppState())
}
