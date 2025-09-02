import Foundation

// MARK: - Общие типы

enum Recurrence: String, Codable, CaseIterable, Identifiable {
    case daily, weekly, monthly, quarterly, yearly
    var id: String { rawValue }
}

// MARK: - Доходы

enum IncomeKind: Codable, Equatable {
    case recurring(Recurrence)
    case oneOff(date: Date, note: String?)

    enum CodingKeys: String, CodingKey { case t, rec, date, note }
    enum T: String, Codable { case recurring, oneOff }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(T.self, forKey: .t) {
        case .recurring: self = .recurring(try c.decode(Recurrence.self, forKey: .rec))
        case .oneOff:    self = .oneOff(date: try c.decode(Date.self, forKey: .date),
                                        note: try c.decodeIfPresent(String.self, forKey: .note))
        }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .recurring(let r): try c.encode(T.recurring, forKey: .t); try c.encode(r, forKey: .rec)
        case .oneOff(let d, let n): try c.encode(T.oneOff, forKey: .t); try c.encode(d, forKey: .date); try c.encodeIfPresent(n, forKey: .note)
        }
    }
}

struct Income: Identifiable, Codable {
    var id: UUID = UUID()
    var title: String
    var amount: Double
    var currency: Currency = .rub
    var kind: IncomeKind = .recurring(.monthly)

    func normalizedMonthlyAmount(for month: Date) -> Double {
        switch kind {
        case .recurring(let r):
            switch r {
            case .daily:     return amount * 365.0 / 12.0
            case .weekly:    return amount * 52.0  / 12.0
            case .monthly:   return amount
            case .quarterly: return amount / 3.0
            case .yearly:    return amount / 12.0
            }
        case .oneOff:
            return 0
        }
    }
}

// MARK: - Расходы

enum ExpenseKind: Codable, Equatable {
    case recurring(Recurrence)
    case oneOff(date: Date?, note: String?)

    enum CodingKeys: String, CodingKey { case t, rec, date, note }
    enum T: String, Codable { case recurring, oneOff }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(T.self, forKey: .t) {
        case .recurring: self = .recurring(try c.decode(Recurrence.self, forKey: .rec))
        case .oneOff:    self = .oneOff(date: try c.decodeIfPresent(Date.self, forKey: .date),
                                        note: try c.decodeIfPresent(String.self, forKey: .note))
        }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .recurring(let r): try c.encode(T.recurring, forKey: .t); try c.encode(r, forKey: .rec)
        case .oneOff(let d, let n): try c.encode(T.oneOff, forKey: .t); try c.encodeIfPresent(d, forKey: .date); try c.encodeIfPresent(n, forKey: .note)
        }
    }
}

struct Expense: Identifiable, Codable {
    var id: UUID = UUID()
    var title: String
    var amount: Double
    var currency: Currency = .rub
    var kind: ExpenseKind = .recurring(.monthly)

    func normalizedMonthlyAmount(for month: Date) -> Double {
        switch kind {
        case .recurring(let r):
            switch r {
            case .daily:     return amount * 365.0 / 12.0
            case .weekly:    return amount * 52.0  / 12.0
            case .monthly:   return amount
            case .quarterly: return amount / 3.0
            case .yearly:    return amount / 12.0
            }
        case .oneOff:
            return 0
        }
    }
}

// MARK: - Долги / Цели / Ежедневные записи

struct Debt: Identifiable, Codable {
    var id: UUID = UUID()
    var title: String
    var obligatoryMonthlyPayment: Double
    var currency: Currency = .rub
}



struct Goal: Identifiable, Codable {
    var id: UUID = UUID()
    var title: String
    var targetAmount: Double
    var currency: Currency = .rub
    var deadline: Date? = nil   // ← НОВОЕ поле. Опционально!

    enum CodingKeys: String, CodingKey {
        case id, title, targetAmount, currency, deadline
    }

    init(id: UUID = UUID(),
         title: String,
         targetAmount: Double,
         currency: Currency = .rub,
         deadline: Date? = nil) {
        self.id = id
        self.title = title
        self.targetAmount = targetAmount
        self.currency = currency
        self.deadline = deadline
    }

    // Мягкая декодировка: если поля не было в старом JSON — подставим дефолт
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decode(String.self, forKey: .title)
        targetAmount = try c.decode(Double.self, forKey: .targetAmount)
        currency = try c.decodeIfPresent(Currency.self, forKey: .currency) ?? .rub
        deadline = try c.decodeIfPresent(Date.self, forKey: .deadline) // может быть nil
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(targetAmount, forKey: .targetAmount)
        try c.encode(currency, forKey: .currency)
        try c.encodeIfPresent(deadline, forKey: .deadline)
    }
    // MARK: - Ежедневные записи (для фактических трат/доходов)

    enum EntryType: String, Codable { case expense, income }

    struct DailyEntry: Identifiable, Codable {
        var id: UUID = UUID()
        var type: EntryType = .expense
        var planned: Bool = false
        var amount: Double
        var currency: Currency = .rub
        var date: Date
        var createdAt: Date = Date()
    }


}

