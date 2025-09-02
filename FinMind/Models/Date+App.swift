import Foundation

extension Calendar {
    static var app: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "ru_RU")
        c.timeZone = .current
        return c
    }
}
extension Date {
    func isSameMonth(as other: Date, calendar: Calendar = .app) -> Bool {
        let a = calendar.dateComponents([.year, .month], from: self)
        let b = calendar.dateComponents([.year, .month], from: other)
        return a.year == b.year && a.month == b.month
    }
    func daysInMonth(calendar: Calendar = .app) -> Int {
        calendar.range(of: .day, in: .month, for: self)?.count ?? 30
    }
    func yearInt(calendar: Calendar = .app) -> Int {
        calendar.component(.year, from: self)
    }
}
