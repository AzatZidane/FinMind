import SwiftUI
import Security

struct SettingsView: View {
    @EnvironmentObject var app: AppState
    @ObservedObject private var profileStore = ProfileStore.shared

    @State private var showWipeAlert = false
    @State private var wipeResult: String?

    private let supportEmail = "ismagilovazat48@gmail.com"

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

                // MARK: Резервная копия
                Section("Резервная копия") {
                    NavigationLink {
                        BackupView().environmentObject(app) // экран из отдельного файла
                    } label: {
                        Label("Экспорт/Импорт JSON", systemImage: "externaldrive.badge.icloud")
                    }
                }

                // MARK: Обратная связь
                Section("Обратная связь") {
                    Button {
                        let subject = "FinMind — отчёт об ошибке"
                        let body = supportBody()
                        let mailto = "mailto:\(supportEmail)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)"
                        if let url = URL(string: mailto) { UIApplication.shared.open(url) }
                    } label: {
                        Label("Сообщить об ошибке", systemImage: "ladybug")
                    }
                }

                // MARK: О приложении
                Section("О приложении") {
                    NavigationLink {
                        PrivacyPolicyView() // или веб-экран с твоим GitHub Pages
                    } label: {
                        Label("Политика конфиденциальности", systemImage: "doc.text.magnifyingglass")
                    }

                    Button(role: .destructive) {
                        showWipeAlert = true
                    } label: {
                        Label("Удалить все данные…", systemImage: "trash")
                    }

                    HStack {
                        Text("Версия")
                        Spacer()
                        Text("\(Bundle.main.appVersion) (\(Bundle.main.appBuild))")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
            .navigationTitle("Настройки")
            .alert("Удалить все данные?", isPresented: $showWipeAlert) {
                Button("Отмена", role: .cancel) {}
                Button("Удалить", role: .destructive) { wipeAllData() }
            } message: {
                Text("Будут удалены все доходы, расходы, долги, цели, дневные записи, сбережения, история чатов и локальные настройки. Действие необратимо.")
            }
            .alert("Готово", isPresented: Binding(get: { wipeResult != nil },
                                                 set: { _ in wipeResult = nil })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(wipeResult ?? "")
            }
        }
    }

    // MARK: Helpers

    private func supportBody() -> String {
        let ver = Bundle.main.appVersion
        let build = Bundle.main.appBuild
        let device = UIDevice.current.model
        let ios = UIDevice.current.systemVersion
        let locale = Locale.current.identifier
        return """
        Опишите проблему тут…

        --- System ---
        App: \(ver) (\(build))
        Device: \(device)
        iOS: \(ios)
        Locale: \(locale)
        ----------------
        """
    }

    private func wipeAllData() {
        // 1) Очистка модели приложения
        app.incomes.removeAll()
        app.expenses.removeAll()
        app.debts.removeAll()
        app.goals.removeAll()
        app.dailyEntries.removeAll()
        app.reserves.removeAll()
        app.rates.updatedAt = nil
        ChatStorage.shared.clear()
        app.forceSave()

        // 2) Системная очистка (UserDefaults / iCloud KVS / Files / Keychain / Cache)
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
            UserDefaults.standard.synchronize()
        }
        NSUbiquitousKeyValueStore.default.removeAll()
        NSUbiquitousKeyValueStore.default.synchronize()

        let fm = FileManager.default
        let roots: [URL?] = [
            fm.urls(for: .documentDirectory, in: .userDomainMask).first,
            fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
            fm.urls(for: .cachesDirectory, in: .userDomainMask).first
        ]
        for root in roots.compactMap({ $0 }) {
            if let items = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) {
                for url in items { try? fm.removeItem(at: url) }
            }
        }

        // Удаляем элементы Keychain для service = "FinMind"
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: "FinMind"]
        SecItemDelete(query as CFDictionary)

        URLCache.shared.removeAllCachedResponses()

        wipeResult = "Данные удалены"
    }
}

// Версия/билд для строки «Версия»
extension Bundle {
    var appVersion: String { object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?" }
    var appBuild: String { object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?" }
}
// Drop-in: чистим iCloud KVS (NSUbiquitousKeyValueStore) целиком
extension NSUbiquitousKeyValueStore {
    /// Полностью очищает iCloud KVS и делает synchronize().
    func removeAll() {
        // dictionaryRepresentation возвращает снимок всех ключей/значений
        for key in dictionaryRepresentation.keys {
            removeObject(forKey: key)
        }
        synchronize()
    }
}