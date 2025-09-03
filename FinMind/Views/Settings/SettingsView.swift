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
                        // Явно задаём id и тип тега — это важно для вывода типов
                        ForEach(AppAppearance.allCases, id: \.self) { ap in
                            Text(ap.title).tag(ap as AppAppearance)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // MARK: Валюта
                Section("Валюта") {
                    Picker("Базовая валюта", selection: $app.baseCurrency) {
                        // Критичный фикс: id и tag с точным типом Currency
                        ForEach(Currency.supported, id: \.code) { c in
                            Text("\(c.code) \(c.symbol)").tag(c as Currency)
                        }
                    }
                }

                // MARK: Курсы
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
