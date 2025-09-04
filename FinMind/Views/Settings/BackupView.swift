import SwiftUI
import UniformTypeIdentifiers

struct BackupView: View {
    @EnvironmentObject var app: AppState

    // Экспорт
    @State private var isExporting = false
    @State private var exportDoc = BackupDocument(data: Data())

    // Импорт
    @State private var isImporting = false

    // Алёрт
    @State private var alert: BackupAlert?

    var body: some View {
        NavigationStack {
            List {
                // ===== РЕЗЕРВНАЯ КОПИЯ =====
                Section {
                    Button {
                        do {
                            let data = try BackupService.shared.makeJSON(from: app)
                            exportDoc = .init(data: data)
                            isExporting = true
                        } catch {
                            alert = .init(title: "Ошибка экспорта",
                                          message: error.localizedDescription)
                        }
                    } label: {
                        Label("Экспорт в JSON…", systemImage: "square.and.arrow.up")
                    }
                    .fileExporter(
                        isPresented: $isExporting,
                        document: exportDoc,
                        contentType: .json,
                        defaultFilename: defaultFilename(),
                        onCompletion: { (result: Result<URL, Error>) in
                            if case .failure(let error) = result {
                                alert = .init(title: "Ошибка экспорта", message: error.localizedDescription)
                            }
                        }
                    )

                    Button {
                        isImporting = true
                    } label: {
                        Label("Восстановить из файла…", systemImage: "square.and.arrow.down")
                    }
                    .fileImporter(
                        isPresented: $isImporting,
                        allowedContentTypes: [.json],
                        allowsMultipleSelection: false,
                        onCompletion: { (result: Result<[URL], Error>) in
                            do {
                                let urls = try result.get()
                                guard let url = urls.first else { return }
                                try importFromURL(url)
                                alert = .init(title: "Готово", message: "Данные успешно восстановлены.")
                            } catch {
                                alert = .init(title: "Ошибка восстановления", message: error.localizedDescription)
                            }
                        }
                    )
                } header: {
                    Text("Резервная копия")
                }

                // ===== ПРИМЕЧАНИЕ =====
                Section {
                    Text("""
Экспорт включает доходы, расходы, долги, цели, «запас», валюты и настройки отображения.
Восстановление перезапишет текущее состояние. Перед восстановлением рекомендуется сделать экспорт текущего состояния.
""")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                } header: {
                    Text("Примечание")
                }
            }
            .navigationTitle("Резервная копия")
            .alert(item: $alert) { a in
                Alert(title: Text(a.title),
                      message: Text(a.message),
                      dismissButton: .default(Text("OK")))
            }
        }
    }

    // MARK: - Helpers

    private func defaultFilename() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd_HHmm"
        return "FinMind-backup-\(fmt.string(from: Date())).json"
    }

    private func importFromURL(_ url: URL) throws {
        // ВАЖНО: security‑scoped доступ, иначе Files вернёт "don't have permission to view it"
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        try BackupService.shared.restore(from: data, into: app)
    }
}

// MARK: - Вспомогательные типы

private struct BackupAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

/// Документ для экспорта JSON через .fileExporter
private struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
