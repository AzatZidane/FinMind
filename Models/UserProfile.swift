import Foundation

struct UserProfile: Codable, Hashable, Equatable {
    var nickname: String?
    var currencyCode: String
    /// 2 = Понедельник, 1 = Воскресенье (как в Calendar.firstWeekday)
    var firstWeekday: Int

    init(
        nickname: String? = nil,
        currencyCode: String = Locale.current.currency?.identifier ?? "RUB",
        firstWeekday: Int = 2
    ) {
        self.nickname = nickname
        self.currencyCode = currencyCode
        self.firstWeekday = firstWeekday
    }
}
