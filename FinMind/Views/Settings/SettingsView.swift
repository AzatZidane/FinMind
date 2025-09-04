import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var app: AppState
    @State private var showWipeAlert = false

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
                Section("Курсы (демо)") {
                    HStack {
                        Text("Обновлено")
                        Spacer()
                        Text(app.rates.updatedAt?.formatted(date: .abbreviated, time: .shortened) ?? "—")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Button("Обновить курсы") {
                        // Демоверсия: только отметка времени
                        app.rates.updatedAt = Date()
                    }
                }

                // MARK: Резервная копия
                Section("Резервная копия") {
                    NavigationLink {
                        BackupView().environmentObject(app)
                    } label: {
                        Label("Экспорт/Импорт JSON", systemImage: "externaldrive.badge.icloud")
                    }
                }

                // MARK: О приложении
                Section("О приложении") {
                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        Label("Политика конфиденциальности", systemImage: "doc.text.magnifyingglass")
                    }

                    Button(role: .destructive) {
                        showWipeAlert = true
                    } label: {
                        Label("Удалить все данные…", systemImage: "trash")
                    }
                    .alert("Удалить все данные?", isPresented: $showWipeAlert) {
                        Button("Отмена", role: .cancel) {}
                        Button("Удалить", role: .destructive) {
                            app.wipeAllData()
                        }
                    } message: {
                        Text("Будут удалены все доходы, расходы, долги, цели, записи, сбережения, истории чатов и локальные настройки.")
                    }
                }
            }
            .navigationTitle("Настройки")
        }
    }
}

// MARK: - Встроенная страница политики

private struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Политика конфиденциальности FinMind")
                    .font(.title2).bold()

                Group {
                    Text("Приложение **FinMind** собирает и обрабатывает только данные, необходимые для работы приложения:")
                    Text("• доходы, расходы, цели и долги, которые пользователь вводит вручную;")
                    Text("• параметры профиля (аватар, никнейм, настройки темы и валюты);")
                    Text("• при желании пользователя — данные «сбережений» (фиат/криптовалюта/металлы).")
                }

                Text("Данные хранятся **локально** на устройстве пользователя. Опционально они могут синхронизироваться через **iCloud** (если включено в настройках устройства).")

                Text("Для работы ИИ-советника запросы передаются на сервер-прокси FinMind, который использует технологию OpenAI. Персональные данные (ФИО, контакты и т.п.) **не собираются и не передаются**.")

                Text("Пользователь может в любой момент удалить все данные в приложении через раздел «Настройки» → «О приложении» → «Удалить все данные…».")

                VStack(alignment: .leading, spacing: 4) {
                    Text("Контакты разработчика:").bold()
                    Text("Email: ismagilovazat48@gmail.com")
                }
            }
            .padding()
        }
        .navigationTitle("Политика")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    SettingsView().environmentObject(AppState())
}
