import Foundation

extension Recurrence {
    var localized: String {
        switch self {
        case .daily:     return "Ежедневно"
        case .weekly:    return "Еженедельно"
        case .monthly:   return "Ежемесячно"
        case .quarterly: return "Ежеквартально"
        case .yearly:    return "Ежегодно"
        }
    }
}
