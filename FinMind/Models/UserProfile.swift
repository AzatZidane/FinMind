import Foundation

struct UserProfile: Codable, Identifiable, Equatable {
    let id: String          // UUID пользователя
    var email: String
    var nickname: String
    var createdAt: Date
    var lastUpdated: Date?  // nil (NaN) при регистрации
}
