import Foundation

// MARK: - Money Formatting
extension Double {
    var moneyString: String {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.locale = Locale.current
        return nf.string(from: NSNumber(value: self)) ?? String(format: "%.2f", self)
    }
}

// MARK: - Date Helpers
extension Calendar {
    static let app = Calendar(identifier: .gregorian)
}

extension Date {
    func startOfMonth() -> Date {
        let cal = Calendar.app
        let comps = cal.dateComponents([.year, .month], from: self)
        return cal.date(from: comps)!
    }
    func endOfMonth() -> Date {
        let cal = Calendar.app
        var comps = DateComponents()
        comps.month = 1
        comps.day = -1
        return cal.date(byAdding: comps, to: self.startOfMonth())!
    }
    func daysInMonth() -> Int {
        let cal = Calendar.app
        let range = cal.range(of: .day, in: .month, for: self.startOfMonth())!
        return range.count
    }
    func yearInt() -> Int {
        return Calendar.app.component(.year, from: self)
    }
    func isSameMonth(as other: Date) -> Bool {
        let cal = Calendar.app
        let c1 = cal.dateComponents([.year, .month], from: self)
        let c2 = cal.dateComponents([.year, .month], from: other)
        return c1.year == c2.year && c1.month == c2.month
    }
}

// MARK: - Periodicity / Categories
enum Periodicity: String, CaseIterable, Identifiable, Codable {
    case weekly = "Еженедельно"
    case monthly = "Ежемесячно"
    case quarterly = "Ежеквартально"
    case annually = "Ежегодно"
    
    var id: String { rawValue }
    
    /// Returns a monthly normalized multiplier (how many times per month this periodicity applies on average).
    var monthlyMultiplier: Double {
        switch self {
        case .weekly: return 52.0 / 12.0
        case .monthly: return 1.0
        case .quarterly: return 4.0 / 12.0 // = 1/3
        case .annually: return 1.0 / 12.0
        }
    }
}

enum EntryType: String, Codable, CaseIterable, Identifiable {
    case income = "Доход"
    case expense = "Расход"
    var id: String { rawValue }
}

enum ExpenseCategory: String, CaseIterable, Identifiable, Codable {
    case food = "Еда"
    case housing = "Жильё"
    case transport = "Транспорт"
    case utilities = "Коммунальные"
    case health = "Здоровье"
    case entertainment = "Развлечения"
    case education = "Образование"
    case clothing = "Одежда"
    case debtPayment = "Платёж по долгу"
    case other = "Другое"
    
    var id: String { rawValue }
}

// MARK: - Incomes
enum IncomeKind: Codable, Equatable {
    case recurring(periodicity: Periodicity, start: Date, end: Date?, isPermanent: Bool)
    case oneOff(date: Date, planned: Bool)
}

struct Income: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var amount: Double
    var kind: IncomeKind
    var note: String?
    
    func isActive(in month: Date) -> Bool {
        switch kind {
        case let .recurring(_, start, end, _):
            let monthStart = month.startOfMonth()
            let monthEnd = month.endOfMonth()
            if start > monthEnd { return false }
            if let e = end, e < monthStart { return false }
            return true
        case .oneOff(let date, _):
            return date.isSameMonth(as: month)
        }
    }
    
    /// Monthly normalized value for recurring incomes.
    func normalizedMonthlyAmount(for month: Date) -> Double {
        switch kind {
        case let .recurring(periodicity, _, end, _):
            // If ended before this month starts -> 0
            if let e = end, e < month.startOfMonth() { return 0 }
            return amount * periodicity.monthlyMultiplier
        case .oneOff:
            return 0
        }
    }
}

// MARK: - Expenses
enum ExpenseKind: Codable, Equatable {
    case recurring(periodicity: Periodicity, start: Date, end: Date?)
    case oneOff(date: Date, planned: Bool)
}

struct Expense: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var amount: Double
    var category: ExpenseCategory
    var kind: ExpenseKind
    var note: String?
    
    func isActive(in month: Date) -> Bool {
        switch kind {
        case let .recurring(_, start, end):
            let monthStart = month.startOfMonth()
            let monthEnd = month.endOfMonth()
            if start > monthEnd { return false }
            if let e = end, e < monthStart { return false }
            return true
        case .oneOff(let date, _):
            return date.isSameMonth(as: month)
        }
    }
    func normalizedMonthlyAmount(for month: Date) -> Double {
        switch kind {
        case let .recurring(periodicity, _, end):
            if let e = end, e < month.startOfMonth() { return 0 }
            return amount * periodicity.monthlyMultiplier
        case .oneOff:
            return 0
        }
    }
}

// MARK: - Debts
enum DebtInputKind: Codable, Equatable {
    case monthlyPayment(amount: Double, isMinimum: Bool)
    case loan(principal: Double, apr: Double, termMonths: Int, graceMonths: Int?, minPayment: Double?)
}

struct Debt: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var createdAt: Date = Date()
    var input: DebtInputKind
    
    /// Obligatory monthly payment to be included in expenses
    var obligatoryMonthlyPayment: Double {
        switch input {
        case .monthlyPayment(let amount, _):
            return max(0, amount)
        case .loan(let principal, let apr, let termMonths, _, let minPayment):
            if let min = minPayment, min > 0 { return min }
            // annuity payment approximation
            let r = apr / 12.0 / 100.0
            guard r > 0, termMonths > 0 else { return principal / Double(max(termMonths, 1)) }
            let numerator = r * principal
            let denominator = 1.0 - pow(1.0 + r, -Double(termMonths))
            let p = numerator / denominator
            return p
        }
    }
}

// MARK: - Goals
struct Goal: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var targetAmount: Double
    var deadline: Date
    var priority: Int // 1..3
    var createdAt: Date = Date()
}

// MARK: - Daily Entries (calendar)
struct DailyEntry: Identifiable, Codable, Equatable {
    var id = UUID()
    var date: Date
    var type: EntryType
    var name: String
    var amount: Double
    var category: ExpenseCategory? // for expenses
    var planned: Bool
    var createdAt: Date = Date()
}
