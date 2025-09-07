import SwiftUI
import UniformTypeIdentifiers
import MessageUI
import Security

// MARK: - Share sheet
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Mail composer
struct MailView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let subject: String
    let to: [String]
    let body: String

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        var parent: MailView
        init(_ parent: MailView) { self.parent = parent }
        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult, error: Error?) {
            parent.dismiss()
        }
    }
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.setSubject(subject)
        vc.setToRecipients(to)
        vc.setMessageBody(body, isHTML: false)
        vc.mailComposeDelegate = context.coordinator
        return vc
    }
    func updateUIViewController(_ vc: MFMailComposeViewController, context: Context) {}
}

// MARK: - Резервная копия (модель пакета)
struct ExportBundle: Codable {
    let version: Int
    let createdAt: Date
    let incomes: [Income]
    let expenses: [Expense]
    let goals: [Goal]
    let debts: [Debt]
}

// MARK: - Системная очистка
enum SecureWiper {
    static func wipeAll() throws {
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
            UserDefaults.standard.synchronize()
        }
        NSUbiquitousKeyValueStore.default.removeAll()
        NSUbiquitousKeyValueStore.default.synchronize()

        let fm = FileManager.default
        let roots: [URL] = [
            fm.urls(for: .documentDirectory, in: .userDomainMask).first!,
            fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!,
            fm.urls(for: .cachesDirectory, in: .userDomainMask).first!
        ]
        for root in roots {
            if let items = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) {
                for url in items { try? fm.removeItem(at: url) }
            }
        }

        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: "FinMind"]
        SecItemDelete(query as CFDictionary)

        URLCache.shared.removeAllCachedResponses()
    }
}

// MARK: - Экран экспорта/импорта
struct BackupView: View {
    @EnvironmentObject var app: AppState
    @State private var showShare = false
    @State private var shareItems: [Any] = []
    @State private var showImporter = false
    @State private var importError: String?

    var body: some View {
        List {
            Section {
                Button { exportJSON() } label: {
                    Label("Экспорт JSON", systemImage: "square.and.arrow.up")
                }
                Button { showImporter = true } label: {
                    Label("Импорт JSON", systemImage: "square.and.arrow.down")
                }
            } footer: {
                Text("Экспорт создаёт файл резервной копии с доходами, расходами, целями и долгами. Импорт перезапишет текущие данные.")
            }
        }
        .navigationTitle("Экспорт/Импорт JSON")
        .sheet(isPresented: $showShare) { ActivityView(items: shareItems) }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url): importJSON(from: url)
            case .failure(let err): importError = err.localizedDescription
            }
        }
        .alert("Ошибка импорта", isPresented: Binding(get: { importError != nil },
                                                      set: { _ in importError = nil })) {
            Button("OK", role: .cancel) {}
        } message: { Text(importError ?? "") }
    }

    private func exportJSON() {
        let bundle = ExportBundle(
            version: 1,
            createdAt: Date(),
            incomes: app.incomes,
            expenses: app.expenses,
            goals: app.goals,
            debts: app.debts
        )
        do {
            let enc = JSONEncoder()
            enc.dateEncodingStrategy = .iso8601
            enc.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes, .sortedKeys]

            let data = try enc.encode(bundle)
            let ts = ISO8601DateFormatter().string(from: bundle.createdAt).replacingOccurrences(of: ":", with: "-")
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("FinMindBackup-\(ts).json")
            try data.write(to: url, options: .atomic)

            shareItems = [url]
            showShare = true
        } catch {
            importError = "Не удалось создать файл: \(error.localizedDescription)"
        }
    }

    private func importJSON(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let dec = JSONDecoder()
            dec.dateDecodingStrategy = .iso8601
            let bundle = try dec.decode(ExportBundle.self, from: data)

            app.incomes  = bundle.incomes
            app.expenses = bundle.expenses
            app.goals    = bundle.goals
            app.debts    = bundle.debts
            app.forceSave()
        } catch {
            importError = "Не удалось импортировать: \(error.localizedDescription)"
        }
    }
}

// MARK: - Настройки
struct SettingsView: View {
    @EnvironmentObject var app: AppState
    @ObservedObject private var profileStore = ProfileStore.shared

    @State private var showWipeAlert = false
    @State private var wipeResult: String?

    @State private var showMail = false
    private let supportEmail = "ismagilovazat48@gmail.com"

    var body: some View {
        NavigationStack {
            List {

                // Профиль
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

                // Отображение
                Section("Отображение") {
                    Toggle("Показывать копейки", isOn: $app.useCents)
                    Picker("Тема", selection: $app.appearance) {
                        ForEach(AppAppearance.allCases, id: \.self) { ap in
                            Text(ap.title).tag(ap as AppAppearance)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Валюта
                Section("Валюта") {
                    Picker("Базовая валюта", selection: $app.baseCurrency) {
                        ForEach(Currency.supported, id: \.code) { c in
                            Text("\(c.code) \(c.symbol)").tag(c as Currency)
                        }
                    }
                }

                // Резервная копия
                Section("Резервная копия") {
                    NavigationLink {
                        BackupView().environmentObject(app)
                    } label: {
                        Label("Экспорт/Импорт JSON", systemImage: "externaldrive.badge.icloud")
                    }
                }

                // Обратная связь
                Section("Обратная связь") {
                    Button {
                        if MFMailComposeViewController.canSendMail() {
                            showMail = true
                        } else {
                            // Фолбэк на mailto:
                            let subject = "FinMind — отчёт об ошибке"
                            let body = supportBody()
                            let mailto = "mailto:\(supportEmail)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)"
                            if let url = URL(string: mailto) { UIApplication.shared.open(url) }
                        }
                    } label: {
                        Label("Сообщить об ошибке", systemImage: "ladybug")
                    }
                }

                // О приложении
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
            .sheet(isPresented: $showMail) {
                MailView(
                    subject: "FinMind — отчёт об ошибке",
                    to: [supportEmail],
                    body: supportBody()
                )
            }
            .alert("Удалить все данные?", isPresented: $showWipeAlert) {
                Button("Отмена", role: .cancel) {}
                Button("Удалить", role: .destructive) { wipeAllData() }
            } message: {
                Text("Будут удалены все доходы, расходы, долги, цели, ежедневные записи, сбережения, история чатов и локальные настройки. Действие необратимо.")
            }
            .alert("Готово", isPresented: Binding(get: { wipeResult != nil },
                                                 set: { _ in wipeResult = nil })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(wipeResult ?? "")
            }
        }
    }

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

        // 2) Системная очистка (UserDefaults/файлы/Keychain/кэш)
        do {
            try SecureWiper.wipeAll()
            wipeResult = "Данные удалены"
        } catch {
            wipeResult = "Очистка завершилась с ошибкой: \(error.localizedDescription)"
        }
    }
}

// Версия/билд для строки «Версия»
extension Bundle {
    var appVersion: String { object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?" }
    var appBuild: String { object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?" }
}

#Preview {
    SettingsView().environmentObject(AppState())
}
