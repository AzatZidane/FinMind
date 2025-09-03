import SwiftUI

private enum AppTab: Hashable {
    case budget, charts, advisor, settings
}

struct RootView: View {
    @EnvironmentObject var app: AppState
    @State private var selected: AppTab = .budget   // по умолчанию открываем «Бюджет»

    var body: some View {
        TabView(selection: $selected) {
            BudgetView()
                .tabItem { Label("Бюджет", systemImage: "list.bullet.rectangle") }
                .tag(AppTab.budget)

            ChartsView()
                .tabItem { Label("Графики", systemImage: "chart.xyaxis.line") }
                .tag(AppTab.charts)

            AdvisorChatView()
                .tabItem { Label("Советник", systemImage: "sparkles") }
                .tag(AppTab.advisor)

            SettingsView()
                .tabItem { Label("Настройки", systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
    }
}
