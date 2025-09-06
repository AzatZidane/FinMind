import Foundation
import Combine

/// Локальное хранилище профиля + вызовы API регистрации/обновления.
final class ProfileStore: ObservableObject {
    static let shared = ProfileStore()

    @Published private(set) var profile: UserProfile?
    var isRegistered: Bool { profile != nil }   // <-- добавили

    private let ud = UserDefaults.standard
    private let key = "user.profile"

    private init() { load() }

    // MARK: - Persist

    private func load() {
        if let data = ud.data(forKey: key),
           let p = try? JSONDecoder().decode(UserProfile.self, from: data) {
            self.profile = p
        }
    }

    private func save() {
        guard let p = profile, let data = try? JSONEncoder().encode(p) else { return }
        ud.set(data, forKey: key)
    }

    /// На всякий случай — удобный сеттер (если где‑то уже использовался).
    func setProfile(_ p: UserProfile?) {
        DispatchQueue.main.async {
            self.profile = p
            self.save()
        }
    }

    func clearLocal() {
        ud.removeObject(forKey: key)
        profile = nil
    }

    // MARK: - API

    /// Регистрация нового пользователя.
    @MainActor
    func register(email: String, nickname: String) async throws {
        let new = UserProfile(
            id: UUID().uuidString,
            email: email,
            nickname: nickname,
            createdAt: Date(),
            lastUpdated: nil
        )
        try await APIClient.shared.register(profile: new) // сервер сам ставит created_at (UTC)
        self.profile = new
        save()
    }

    /// Обновление имени/почты.
    @MainActor
    func update(email: String, nickname: String) async throws {
        guard var current = self.profile else { return }
        current.email = email
        current.nickname = nickname

        try await APIClient.shared.updateProfile(profile: current)

        // Успешно: фиксируем локально и проставим lastUpdated (для UI).
        current.lastUpdated = Date()
        self.profile = current
        save()
    }
}
