import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store = ProfileStore.shared
    @State private var email: String = ""
    @State private var nickname: String = ""
    @State private var errorText: String?
    @State private var isLoading = false

    var body: some View {
        Form {
            TextField("Email", text: $email)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)

            TextField("Имя", text: $nickname)

            if let e = errorText {
                Text(e).foregroundStyle(.red)
            }

            Button("Сохранить") {
                Task { await doSave() }
            }
            .disabled(isLoading)
        }
        .onAppear {
            email = store.profile?.email ?? ""
            nickname = store.profile?.nickname ?? ""
        }
        .navigationTitle("Редактировать профиль")
    }

    private func doSave() async {
        guard var profile = store.profile else { return }
        profile.email = email
        profile.nickname = nickname
        isLoading = true
        defer { isLoading = false }
        do {
            try await APIClient.shared.updateProfile(profile: profile)
            store.setProfile(profile) // локально сохранить
            dismiss()
        } catch {
            errorText = "На данный момент эта функция не доступна, попробуйте через 12 часов"
        }
    }
}
