import SwiftUI

struct DiagnosticsView: View {
    @AppStorage("diag.enabled") private var enabled = false
    @State private var logText: String = ""
    @State private var showShare = false
    @State private var showMail = false
    @State private var showMailUnavailable = false

    private var logURL: URL { AppLog.shared.currentFileURL() }

    var body: some View {
        List {
            Section("Сбор диагностических данных") {
                Toggle("Включить расширенное логирование", isOn: $enabled)
                Text("Когда включено, приложение пишет тех. события в локальный файл (без персональных данных). Вы можете отправить журнал в поддержку.")
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
                    Button("Поделиться файлом…") {
                        showShare = true
                    }
                    Button("Отправить по e‑mail") {
                        if MailComposerView.canSendMail() {
                            showMail = true
                        } else {
                            showMailUnavailable = true
                        }
                    }
                    .tint(.blue)
                    Button("Очистить", role: .destructive) {
                        AppLog.shared.clear()
                        logText = ""
                    }
                }
            }
        }
        .navigationTitle("Диагностика")
        .onAppear { logText = AppLog.shared.readTail() }
        .sheet(isPresented: $showShare) {
            ActivityView(activityItems: [logURL])
        }
        .sheet(isPresented: $showMail) {
            MailComposerView(
                subject: "FinMind diagnostics log",
                recipients: ["ismagilovazat48@gmail.com"],
                body: "Журнал во вложении.",
                attachments: [
                    .init(data: (try? Data(contentsOf: logURL)) ?? Data(),
                          mimeType: "text/plain",
                          fileName: "finmind.log")
                ]
            )
        }
        .alert("Почта недоступна", isPresented: $showMailUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("На устройстве не настроено приложение «Почта». Вы можете сохранить файл через «Поделиться файлом…» и отправить вручную.")
        }
    }
}
