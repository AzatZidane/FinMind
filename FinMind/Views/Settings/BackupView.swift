import SwiftUI

struct BackupView: View {
    @EnvironmentObject var app: AppState

    @State private var isExporting = false
    @State private var isImporting = false
    @State private var exportDoc = BackupDocument(data: Data())
    @State private var alertMessage: String?
    @State private var showAlert = false

    private var defaultFilename: String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd_HHmm"
        return "FinMind-backup-\(df.string(from: Date())).json"
    }

    var body: some View {
        Form {
            Section(header: Text("Резервная копия")) {
                Button {
                    do {
                        let json = try BackupCodec.makeJSON(from: app)
                        exportDoc = BackupDocument(data: json)
                        isExporting = true
                    } catch {
                        show("Не удалось сформировать JSON: \(error.localizedDescription)")
                    }
                } label: {
                    Label("Экспорт в JSON…", systemImage: "square.and.arrow.up")
                }

                Button(role: .none) {
                    isImporting = true
                } label: {
                    Label("Восстановить из файла…", systemImage: "square.and.arrow.down")
                }
            }

            Section(header: Text("Примечание")) {
                Text("Экспорт включает доходы, расходы, долги и цели. Восстановление перезапишет текущее состояние. Перед восстановлением рекомендуется сделать экспорт текущих данных.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Резервная копия")
        .fileExporter(isPresented: $isExporting,
                      document: exportDoc,
                      contentType: .json,
                      defaultFilename: defaultFilename) { result in
            if case .failure(let err) = result {
                show("Ошибка при сохранении: \(err.localizedDescription)")
            }
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get()
                let data = try Data(contentsOf: url)
                try BackupCodec.applyJSON(data, to: app)
            } catch {
                show("Ошибка при восстановлении: \(error.localizedDescription)")
            }
        }
        .alert("Операция резервной копии", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            if let message = alertMessage {
                Text(message)
            }
        }
    }

    private func show(_ msg: String) {
        alertMessage = msg
        showAlert = true
    }
}

#Preview {
    BackupView().environmentObject(AppState())
}
