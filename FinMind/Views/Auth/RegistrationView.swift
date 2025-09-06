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
                        .autocorrectionDisabled()
                    TextField("Имя (никнейм)", text: $nickname)
                        .textInputAutocapitalization(.words)
                }

                if let e = errorText {
                    Text(e).foregroundStyle(.red).font(.footnote)
                }

                Section {
                    Button {
                        Task { await doRegister() }
                    } label: {
                        if isLoading { ProgressView() }
                        else { Text("Зарегистрироваться") }
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

    private var canSubmit: Bool {
        validateEmail(email) && nickname.trimmingCharacters(in: .whitespaces).count >= 2
    }

    private func validateEmail(_ s: String) -> Bool {
        // простая проверка
        let r = #/^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$/#i
        return s.wholeMatch(of: r) != nil
    }

    private func doRegister() async {
        errorText = nil
        isLoading = true
        defer { isLoading = false }
        do {
            try await ProfileStore.shared.register(email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                                                   nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines))
            dismiss()
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? "Неизвестная ошибка"
        }
    }
}
