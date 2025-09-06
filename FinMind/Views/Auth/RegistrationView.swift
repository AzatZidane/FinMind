import SwiftUI

struct RegistrationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email: String = ""
    @State private var nickname: String = ""
    @State private var isLoading: Bool = false
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
                        // Без if внутри label — только прозрачность/оверлей
                        ZStack {
                            Text("Зарегистрироваться")
                                .opacity(isLoading ? 0 : 1)
                            ProgressView()
                                .opacity(isLoading ? 1 : 0)
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
        validateEmail(email) &&
        nickname.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
    }

    private func validateEmail(_ s: String) -> Bool {
        // Совместимо со старыми Swift: без новых regex‑литералов
        let pattern = "^[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}$"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return false
        }
        let range = NSRange(location: 0, length: s.utf16.count)
        return regex.firstMatch(in: s, options: [], range: range) != nil
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
