import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        NavigationStack {
            List {
                Section("Отображение") {
                    Toggle("Показывать копейки", isOn: $app.useCents)
                    Picker("Тема", selection: $app.appearance) {
                        ForEach(AppAppearance.allCases) { ap in
                            Text(ap.title).tag(ap)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Валюта") {
                    Picker("Базовая валюта", selection: $app.baseCurrency) {
                        ForEach(Currency.supported) { Text("\($0.code) \($0.symbol)").tag($0) }
                    }
                }

                Section("Курсы (демо)") {
                    HStack {
                        Text("Обновлено")
                        Spacer()
                        Text(app.rates.updatedAt?.formatted(date: .abbreviated, time: .shortened) ?? "—")
                            .foregroundStyle(.secondary)
                    }
                    Button("Обновить курсы") {
                        Task { await app.updateRates() }
                    }
                }

                Section("Резервная копия") {
                    NavigationLink {
                        BackupView().environmentObject(app)
                    } label: {
                        Label("Экспорт/Импорт JSON", systemImage: "externaldrive.badge.icloud")
                    }
                }
            }
            .navigationTitle("Настройки")
        }
    }
}

#Preview {
    SettingsView().environmentObject(AppState())
}
