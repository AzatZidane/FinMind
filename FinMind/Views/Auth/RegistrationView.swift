import SwiftUI

struct RegistrationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var nickname = ""
    @State private var isLoading = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Аккаунт") {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)

                    TextField("Имя (никнейм)", text: $nickname)
                        .textInputAutocapitalization(.words)
                }

                if let e = errorText {
                    Text(e)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Section {
                    Button(action: {
                        Task { await doRegister() }
                    }) {
                        // Текст всегда один и тот же; индикатор поверх — когда isLoading = true.
                        Text("Зарегистрироваться")
                            .opacity(isLoading ? 0 : 1)
                            .overlay {
                                if isLoading { ProgressView() }
                            }
                    }
                    .disabled(!canSubmit || isLoading)

                    Button("Позже", role: .cancel) {
                        dismiss()
                    }
                }
            }
            .navigationTitle("Регистрация")
        }
    }

    // MARK: - Validation
    private var canSubmit: Bool {
        validateEmail(email) && nickname.trimmingCharacters(in: .whitespaces).count >= 2
    }

    private func validateEmail(_ s: String) -> Bool {
        // Простая проверка корректности email (без внешних зависимостей на клиенте)
        let r = #/^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$/#i
        return s.wholeMatch(of: r) != nil
    }

    // MARK: - Actions
    private func doRegister() async {
        errorText = nil
        isLoading = true
        defer { isLoading = false }

        do {
            try await ProfileStore.shared.register(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            dismiss()
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? "Неизвестная ошибка"
        }
    }
}

#Preview {
    RegistrationView()
}
