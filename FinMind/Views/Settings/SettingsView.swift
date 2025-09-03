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
                        // Жёсткая типизация: id и tag с точным типом
                        ForEach(AppAppearance.allCases, id: \.self) { ap in
                            Text(ap.title).tag(ap as AppAppearance)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // MARK: Валюта
                Section("Валюта") {
                    Picker("Базовая валюта", selection: $app.baseCurrency) {
                        // Жёсткая типизация: id и tag с точным типом Currency
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
                            Task { await app.updateRates() }
                        }
                    }
                } header: {
                    Text("Курсы (демо)")
                }

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
