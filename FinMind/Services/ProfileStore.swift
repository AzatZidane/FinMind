import Foundation
import Combine

/// Локальное хранилище профиля + вызовы API регистрации
final class ProfileStore: ObservableObject {
    static let shared = ProfileStore()
    private init() { load() }

    @Published private(set) var profile: UserProfile?
    var isRegistered: Bool { profile != nil }

    private let ud = UserDefaults.standard
    private let key = "user.profile"

    private func load() {
        if let data = ud.data(forKey: key),
           let p = try? JSONDecoder().decode(UserProfile.self, from: data) {
            self.profile = p
        }
    }
    private func save() {
        if let p = profile, let data = try? JSONEncoder().encode(p) {
            ud.set(data, forKey: key)
        }
    }

    /// Создаёт профиль локально и отправляет на сервер
    @MainActor
    func register(email: String, nickname: String) async throws {
        let new = UserProfile(
            id: UUID().uuidString,
            email: email,
            nickname: nickname,
            createdAt: Date()
        )
        // сначала отправим на сервер; если ок — сохраним локально
        try await APIClient.shared.register(profile: new)
        self.profile = new
        save()
    }

    /// Удаление локальной копии (для отладки)
    func clearLocal() {
        ud.removeObject(forKey: key)
        profile = nil
    }
}
