import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        NavigationStack {
            List {
                // MARK: Отображение
                Section("Отображение") {
                    Toggle("Показывать копейки", isOn: $app.useCents)

                    Picker("Тема", selection: $app.appearance) {
                        ForEach(AppAppearance.allCases, id: \.self) { ap in
                            Text(ap.title).tag(ap as AppAppearance)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // MARK: Валюта
                Section("Валюта") {
                    Picker("Базовая валюта", selection: $app.baseCurrency) {
                        ForEach(Currency.supported, id: \.code) { c in
                            Text("\(c.code) \(c.symbol)").tag(c as Currency)
                        }
                    }
                }

                // MARK: Курсы (демо)
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Обновлено")
                            Spacer()
                            Text(app.rates.updatedAt?.formatted(date: .abbreviated, time: .shortened) ?? "—")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Button("Обновить курсы") {
                            // Без асинхронщины — ничего не «залипнет»
                            app.rates.updatedAt = Date()
                        }
                    }
                } header: { Text("Курсы (демо)") }

                // MARK: Бэкап
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
