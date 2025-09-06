import Foundation

struct UserProfile: Codable, Identifiable, Equatable {
    let id: String
    var email: String
    var nickname: String
    var createdAt: Date
    var lastUpdated: Date?   // nil при регистрации; обновляем при изменении
}
