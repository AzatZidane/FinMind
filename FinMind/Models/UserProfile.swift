import Foundation

struct UserProfile: Codable, Identifiable, Equatable {
    let id: String          // UUID, сгенерированный на устройстве
    var email: String
    var nickname: String
    var createdAt: Date
}