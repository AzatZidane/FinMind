import SwiftUI

private enum AppTab: Hashable {
    case advisor, budget, settings
}

struct RootView: View {
    @EnvironmentObject var app: AppState
    @State private var selected: AppTab = .advisor   // по умолчанию открываем Советника

    var body: some View {
        TabView(selection: $selected) {
            AdvisorChatView()
                .tabItem { Label("Советник", systemImage: "sparkles") }
                .tag(AppTab.advisor)

            BudgetView()
                .tabItem { Label("План", systemImage: "chart.pie.fill") }
                .tag(AppTab.budget)

            SettingsView()
                .tabItem { Label("Настройки", systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
    }
}
