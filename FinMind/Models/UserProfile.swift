import Foundation

struct UserProfile: Codable, Identifiable, Equatable {
    let id: String          // UUID, сгенерированный на устройстве
    var email: String
    var nickname: String
    var createdAt: Date
}
struct UserProfile: Codable, Identifiable, Equatable {
    let id: String
    var email: String
    var nickname: String
    var createdAt: Date
    var lastUpdated: Date?   // может быть nil
}
