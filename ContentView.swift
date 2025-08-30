import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            OverviewView()
                .tabItem { Label("Обзор", systemImage: "chart.pie") }
            PlanView()
                .tabItem { Label("План", systemImage: "list.bullet.rectangle") }
            CalendarView()
                .tabItem { Label("Календарь", systemImage: "calendar") }
            SettingsView()
                .tabItem { Label("Настройки", systemImage: "gearshape") }
        }
    }
}

#Preview { ContentView() }
