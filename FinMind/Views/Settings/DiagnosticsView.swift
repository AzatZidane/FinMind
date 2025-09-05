import SwiftUI

struct DiagnosticsView: View {
    @AppStorage("diag.enabled") private var enabled = false
    @State private var logText: String = ""

    var body: some View {
        List {
            Section("Сбор диагностических данных") {
                Toggle("Включить расширенное логирование", isOn: $enabled)
                Text("Когда включено, приложение пишет тех. события в локальный файл (без персональных данных). Вы можете поделиться журналом со службой поддержки.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Журнал") {
                if logText.isEmpty {
                    Text("Пока нет данных").foregroundStyle(.secondary)
                } else {
                    ScrollView {
                        Text(logText)
                            .font(.system(.footnote, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 300)
                }

                HStack {
                    Button("Обновить") { logText = AppLog.shared.readTail() }
                    Spacer()
                    ShareLink("Поделиться…", item: AppLog.shared.currentFileURL())
                        .disabled(logText.isEmpty)
                    Button("Очистить", role: .destructive) {
                        AppLog.shared.clear()
                        logText = ""
                    }
                }
            }
        }
        .navigationTitle("Диагностика")
        .onAppear { logText = AppLog.shared.readTail() }
    }
}
