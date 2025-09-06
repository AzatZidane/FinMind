import SwiftUI

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var profileStore = ProfileStore.shared

    @State private var message = ""
    @State private var isSending = false
    @State private var errorText: String?

    private var canSend: Bool {
        guard profileStore.profile?.id != nil else { return false }
        return !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    var body: some View {
        Form {
            if profileStore.profile == nil {
                Text("Для отправки обратной связи требуется аккаунт. Зарегистрируйтесь в разделе «Профиль».")
                    .foregroundStyle(.secondary)
            }

            Section("Сообщение") {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $message)
                        .frame(minHeight: 160)

                    if message.isEmpty {
                        Text("Опишите проблему…")
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                            .allowsHitTesting(false)
                    }
                }
            }

            if let e = errorText {
                Text(e).foregroundStyle(.red).font(.footnote)
            }

            Section {
                Button {
                    Task { await send() }
                } label: {
                    if isSending { ProgressView() } else { Text("Отправить") }
                }
                .disabled(!canSend)
            }
        }
        .navigationTitle("Сообщить об ошибке")
    }

    private func send() async {
        guard let id = profileStore.profile?.id else { return }
        isSending = true
        defer { isSending = false }

        do {
            try await APIClient.shared.sendFeedback(userId: id, message: message)
            dismiss()
        } catch {
            errorText = "Не удалось отправить. Попробуйте позже."
        }
    }
}

#Preview {
    FeedbackView()
}
