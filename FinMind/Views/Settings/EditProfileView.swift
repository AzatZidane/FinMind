import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = ProfileStore.shared

    @State private var email: String = ""
    @State private var nickname: String = ""
    @State private var errorText: String?
    @State private var isLoading = false

    var body: some View {
        Form {
            Section("Профиль") {
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)

                TextField("Имя (никнейм)", text: $nickname)
                    .textInputAutocapitalization(.words)
            }

            if let e = errorText {
                Text(e).font(.footnote).foregroundStyle(.red)
            }

            Section {
                Button {
                    Task { await save() }
                } label: {
                    if isLoading { ProgressView() }
                    else { Text("Сохранить") }
                }
                .disabled(!canSubmit || isLoading)
            }
        }
        .navigationTitle("Редактировать профиль")
        .onAppear {
            email = store.profile?.email ?? ""
            nickname = store.profile?.nickname ?? ""
        }
    }

    // MARK: - Validation

    private var canSubmit: Bool {
        validateEmail(email)
        && nickname.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
    }

    private func validateEmail(_ s: String) -> Bool {
        // Без современных regex-литералов — работает на любом Swift
        let pattern = "^[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}$"
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return false }
        let range = NSRange(location: 0, length: s.utf16.count)
        return re.firstMatch(in: s, options: [], range: range) != nil
    }

    // MARK: - Actions

    private func save() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await store.update(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            dismiss()
        } catch {
            // Текст из ТЗ: показать пользователю
            errorText = "На данный момент эта функция не доступна, попробуйте через 12 часов"
        }
    }
}
