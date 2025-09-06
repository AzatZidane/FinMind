import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var app: AppState
    @ObservedObject private var profileStore = ProfileStore.shared   // <-- наблюдаем профиль

    @State private var showWipeAlert = false

    var body: some View {
        NavigationStack {
            List {

                // MARK: Профиль
                Section("Профиль") {
                    if let p = profileStore.profile {
                        LabeledContent("Имя", value: p.nickname)
                        LabeledContent("Почта", value: p.email)
                        if let dt = p.lastUpdated {
                            LabeledContent("Изменено") {
                                Text(dt.formatted(date: .abbreviated, time: .shortened))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        NavigationLink("Редактировать") { EditProfileView() }
                    } else {
                        Text("Не зарегистрирован").foregroundStyle(.secondary)
                        NavigationLink("Зарегистрироваться") { RegistrationView() }
                    }
                }

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

                // MARK: Диагностика
                Section("Диагностика") {
                    NavigationLink {
                        DiagnosticsView()
                    } label: {
                        Label("Логи и отчёты", systemImage: "wrench.adjustable")
                    }
                }

                // MARK: О приложении
                Section("О приложении") {
                    NavigationLink { PrivacyPolicyView() } label: {
                        Label("Политика конфиденциальности", systemImage: "doc.text.magnifyingglass")
                    }

                    Button(role: .destructive) {
                        showWipeAlert = true
                    } label: {
                        Label("Удалить все данные…", systemImage: "trash")
                    }
                    .alert("Удалить все данные?", isPresented: $showWipeAlert) {
                        Button("Отмена", role: .cancel) {}
                        Button("Удалить", role: .destructive) { wipeAllData() }
                    } message: {
                        Text("Будут удалены все доходы, расходы, долги, цели, ежедневные записи, сбережения, история чатов и локальные настройки.")
                    }
                }
            }
            .navigationTitle("Настройки")
        }
    }

    // MARK: - Полная локальная очистка
    private func wipeAllData() {
        app.incomes.removeAll()
        app.expenses.removeAll()
        app.debts.removeAll()
        app.goals.removeAll()
        app.dailyEntries.removeAll()
        app.reserves.removeAll()
        app.rates.updatedAt = nil
        ChatStorage.shared.clear()
        app.forceSave()
    }
}

#Preview {
    SettingsView().environmentObject(AppState())
}
