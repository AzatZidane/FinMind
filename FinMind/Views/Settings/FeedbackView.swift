import SwiftUI

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var message = ""
    @State private var errorText: String?
    @State private var isLoading = false

    var body: some View {
        Form {
            Section("Опишите проблему") {
                TextEditor(text: $message)
                    .frame(height: 150)
            }

            if let e = errorText {
                Text(e).foregroundStyle(.red)
            }

            Button("Отправить") {
                Task { await doSend() }
            }
            .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
        }
        .navigationTitle("Сообщить об ошибке")
    }

    private func doSend() async {
        guard let userId = ProfileStore.shared.profile?.id else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            try await APIClient.shared.sendFeedback(userId: userId, message: message)
            dismiss()
        } catch {
            errorText = "Сервис обратной связи временно недоступен, попробуйте через 12 часов"
        }
    }
}
