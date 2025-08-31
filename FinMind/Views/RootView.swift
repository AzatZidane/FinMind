import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            // 1. Бюджет
            BudgetView()
                .tabItem { Label(UIStrings.tab1, systemImage: "chart.pie.fill") }

            // 2. План (используем экран целей как «план»)
            GoalsListView()
                .tabItem { Label(UIStrings.tab2, systemImage: "list.bullet.rectangle") }

            // 3. Советник (новый экран‑заглушка с действиями)
            AdvisorView()
                .tabItem { Label(UIStrings.tab3, systemImage: "lightbulb") }

            // 4. Профиль (настройки/сброс)
            SettingsView()
                .tabItem { Label(UIStrings.tab4, systemImage: "person.circle") }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AppState())
}
