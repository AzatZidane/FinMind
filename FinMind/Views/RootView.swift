import SwiftUI

struct RootView: View {
    @State private var showRegistration = false

    var body: some View {
        TabView {
            BudgetView()
                .tabItem { Label("Бюджет", systemImage: "list.bullet.rectangle") }

            ChartsView()
                .tabItem { Label("Графики", systemImage: "chart.line.uptrend.xyaxis") }

            AdvisorView()
                .tabItem { Label("Советник", systemImage: "brain.head.profile") }

            SettingsView()
                .tabItem { Label("Настройки", systemImage: "gear") }
        }
        .onAppear {
            if !ProfileStore.shared.isRegistered {
                showRegistration = true
            }
        }
        .fullScreenCover(isPresented: $showRegistration) {
            RegistrationView()
        }
    }
}

#Preview { RootView() }
