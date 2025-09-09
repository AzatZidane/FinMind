import Foundation
import Combine
import SwiftUI

// Тема приложения
enum AppAppearance: String, Codable, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }

    var swiftUIColorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    var title: String {
        switch self {
        case .system: return "Как в системе"
        case .light:  return "Светлая"
        case .dark:   return "Тёмная"
        }
    }
}

final class AppState: ObservableObject, Codable {
    // MARK: - Данные
    @Published var incomes: [Income]
    @Published var expenses: [Expense]
    @Published var debts: [Debt]
    @Published var goals: [Goal]
    @Published var dailyEntries: [DailyEntry]
    @Published var firstUseAt: Date

    // Валюта/курсы/запас
    @Published var baseCurrency: Currency
    @Published var reserves: [ReserveHolding]
    @Published var rates: ExchangeRates

    // НОВОЕ: настройки отображения
    @Published var useCents: Bool      // показывать копейки?
    @Published var appearance: AppAppearance // тема

    enum CodingKeys: String, CodingKey {
        case incomes, expenses, debts, goals, dailyEntries, firstUseAt
        case baseCurrency, reserves, rates
        case useCents, appearance
    }

    init(incomes: [Income] = [],
         expenses: [Expense] = [],
         debts: [Debt] = [],
         goals: [Goal] = [],
         dailyEntries: [DailyEntry] = [],
         firstUseAt: Date = Date(),
         baseCurrency: Currency = .rub,
         reserves: [ReserveHolding] = [],
         rates: ExchangeRates = ExchangeRates(),
         useCents: Bool = false,                        // по умолчанию без копеек
         appearance: AppAppearance = .system) {

        self.incomes = incomes
        self.expenses = expenses
        self.debts = debts
        self.goals = goals
        self.dailyEntries = dailyEntries
        self.firstUseAt = firstUseAt
        self.baseCurrency = baseCurrency
        self.reserves = reserves
        self.rates = rates
        self.useCents = useCents
        self.appearance = appearance
    }

    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.incomes = try c.decodeIfPresent([Income].self, forKey: .incomes) ?? []
        self.expenses = try c.decodeIfPresent([Expense].self, forKey: .expenses) ?? []
        self.debts = try c.decodeIfPresent([Debt].self, forKey: .debts) ?? []
        self.goals = try c.decodeIfPresent([Goal].self, forKey: .goals) ?? []
        self.dailyEntries = try c.decodeIfPresent([DailyEntry].self, forKey: .dailyEntries) ?? []
        self.firstUseAt = try c.decodeIfPresent(Date.self, forKey: .firstUseAt) ?? Date()
        self.baseCurrency = try c.decodeIfPresent(Currency.self, forKey: .baseCurrency) ?? .rub
        self.reserves = try c.decodeIfPresent([ReserveHolding].self, forKey: .reserves) ?? []
        self.rates = try c.decodeIfPresent(ExchangeRates.self, forKey: .rates) ?? ExchangeRates()
        self.useCents = try c.decodeIfPresent(Bool.self, forKey: .useCents) ?? false
        self.appearance = try c.decodeIfPresent(AppAppearance.self, forKey: .appearance) ?? .system
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(incomes, forKey: .incomes)
        try c.encode(expenses, forKey: .expenses)
        try c.encode(debts, forKey: .debts)
        try c.encode(goals, forKey: .goals)
        try c.encode(dailyEntries, forKey: .dailyEntries)
        try c.encode(firstUseAt, forKey: .firstUseAt)
        try c.encode(baseCurrency, forKey: .baseCurrency)
        try c.encode(reserves, forKey: .reserves)
        try c.encode(rates, forKey: .rates)
        try c.encode(useCents, forKey: .useCents)
        try c.encode(appearance, forKey: .appearance)
    }

    // MARK: - Автосохранение
    private var cancellables = Set<AnyCancellable>()
    func startAutoSave() {
        let updates: [AnyPublisher<Void, Never>] = [
            $incomes.map { _ in () }.eraseToAnyPublisher(),
            $expenses.map { _ in () }.eraseToAnyPublisher(),
            $debts.map { _ in () }.eraseToAnyPublisher(),
            $goals.map { _ in () }.eraseToAnyPublisher(),
            $dailyEntries.map { _ in () }.eraseToAnyPublisher(),
            $baseCurrency.map { _ in () }.eraseToAnyPublisher(),
            $reserves.map { _ in () }.eraseToAnyPublisher(),
            $rates.map { _ in () }.eraseToAnyPublisher(),
            $useCents.map { _ in () }.eraseToAnyPublisher(),     // новое
            $appearance.map { _ in () }.eraseToAnyPublisher()    // новое
        ]
        // В AppState.startAutoSave()
        Publishers.MergeMany(updates)
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main) // можно 300–600
            .sink { [weak self] _ in
                guard let self = self else { return }
                // Сохраняем НЕ на главном потоке
                Persistence.shared.saveAsync(self)
            }
            .store(in: &cancellables)

    }

    func forceSave() {
        do { try Persistence.shared.save(self) }
        catch { print("Persistence forceSave error:", error.localizedDescription) }
    }

    // MARK: - Мутации (без изменений)
    func addIncome(_ income: Income) { incomes.append(income) }
    func removeIncome(_ income: Income) { incomes.removeAll { $0.id == income.id } }

    func addExpense(_ expense: Expense) { expenses.append(expense) }
    func removeExpense(_ expense: Expense) { expenses.removeAll { $0.id == expense.id } }

    func addDebt(_ debt: Debt) { debts.append(debt) }
    func removeDebt(_ debt: Debt) { debts.removeAll { $0.id == debt.id } }

    func addGoal(_ goal: Goal) { goals.append(goal) }
    func removeGoal(_ goal: Goal) { goals.removeAll { $0.id == goal.id } }

    func addDailyEntry(_ entry: DailyEntry) { dailyEntries.append(entry) }
    func removeDailyEntry(_ entry: DailyEntry) { dailyEntries.removeAll { $0.id == entry.id } }

    func addReserve(_ r: ReserveHolding) { reserves.append(r) }
    func removeReserve(_ r: ReserveHolding) { reserves.removeAll { $0.id == r.id } }

    // MARK: - Форматирование/конвертация
    func fractionDigits(for currency: Currency) -> Int {
        useCents ? currency.fractionDigits : 0
    }

    func formatMoney(_ amount: Double, currency: Currency? = nil) -> String {
        let c = currency ?? baseCurrency
        let digits = fractionDigits(for: c)

        // Глушим NaN/±inf, чтобы они не ушли дальше в UI
        let safe = amount.isFinite ? amount : 0

        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.usesGroupingSeparator = true
        nf.groupingSeparator = "."
        nf.decimalSeparator = ","
        nf.minimumFractionDigits = digits
        nf.maximumFractionDigits = digits
        let s = nf.string(from: Decimal(safe) as NSDecimalNumber) ?? "0"
        return "\(s) \(c.symbol)"
    }


    func toBase(_ amount: Decimal, from currency: Currency) -> Decimal {
        rates.convert(amount: amount, from: currency, to: baseCurrency) ?? 0
    }

    func reserveValueInBase(_ r: ReserveHolding) -> Decimal {
        switch r.kind {
        case .fiat(let cur):   return toBase(r.amount, from: cur)
        case .crypto(let k):   return rates.cryptoTo(currency: baseCurrency, crypto: k, amount: r.amount) ?? 0
        case .metal(let m):
            let ounces: Decimal = (r.unit == .gram) ? (r.amount / Decimal(31.1034768)) : r.amount
            return rates.metalTo(currency: baseCurrency, metal: m, amountInTroyOunces: ounces) ?? 0
        }
    }

    func totalReservesInBase() -> Decimal {
        reserves.reduce(0) { $0 + reserveValueInBase($1) }
    }

    // … Метрики остаются без изменений …
    private var now: Date { Date() }

    func totalNormalizedMonthlyRecurringIncome(for month: Date = Date()) -> Double {
        let sum: Decimal = incomes.reduce(0) { acc, inc in
            acc + toBase(Decimal(inc.normalizedMonthlyAmount(for: month)), from: inc.currency)
        }
        return NSDecimalNumber(decimal: sum).doubleValue
    }

    func totalRecurringAnnualIncome(for year: Int = Calendar.app.component(.year, from: Date())) -> Double {
        var total: Double = 0
        let cal = Calendar.app
        for m in 1...12 {
            var comps = DateComponents(); comps.year = year; comps.month = m; comps.day = 1
            if let month = cal.date(from: comps) { total += totalNormalizedMonthlyRecurringIncome(for: month) }
        }
        return total
    }

    func totalOneOffIncome(for year: Int = Calendar.app.component(.year, from: Date())) -> Double {
        let sum: Decimal = incomes.reduce(0) { acc, inc in
            if case .oneOff(let date, _) = inc.kind, date.yearInt() == year {
                return acc + toBase(Decimal(inc.amount), from: inc.currency)
            }
            return acc
        }
        return NSDecimalNumber(decimal: sum).doubleValue
    }

    func totalAnnualIncome(for year: Int = Calendar.app.component(.year, from: Date())) -> Double {
        totalRecurringAnnualIncome(for: year) + totalOneOffIncome(for: year)
    }

    func totalNormalizedMonthlyRecurringExpense(for month: Date = Date()) -> Double {
        var base: Decimal = expenses.reduce(0) { acc, e in
            acc + toBase(Decimal(e.normalizedMonthlyAmount(for: month)), from: e.currency)
        }
        base += debts.reduce(0) { acc, d in
            acc + toBase(Decimal(d.obligatoryMonthlyPayment), from: d.currency)
        }
        return NSDecimalNumber(decimal: base).doubleValue
    }

    func plannedMonthlyExpense(for month: Date = Date()) -> Double {
        let recurring = totalNormalizedMonthlyRecurringExpense(for: month)
        let planned: Decimal = dailyEntries
            .filter { $0.type == .expense && $0.planned && $0.date.isSameMonth(as: month) }
            .reduce(0) { $0 + toBase(Decimal($1.amount), from: $1.currency) }
        return recurring + NSDecimalNumber(decimal: planned).doubleValue
    }

    func actualMonthlyExpense(for month: Date = Date()) -> Double {
        let sum: Decimal = dailyEntries
            .filter { $0.type == .expense && !$0.planned && $0.date.isSameMonth(as: month) }
            .reduce(0) { $0 + toBase(Decimal($1.amount), from: $1.currency) }
        return NSDecimalNumber(decimal: sum).doubleValue
    }

    func annualExpense(for year: Int = Calendar.app.component(.year, from: Date())) -> Double {
        var total: Double = 0
        let cal = Calendar.app
        for m in 1...12 {
            var comps = DateComponents(); comps.year = year; comps.month = m; comps.day = 1
            if let month = cal.date(from: comps) { total += plannedMonthlyExpense(for: month) }
        }
        return total
    }

    func plannedDailyAverageCurrentMonth() -> Double {
        let days = Double(now.daysInMonth())
        let plan = plannedMonthlyExpense(for: now)
        return days > 0 ? plan / days : 0
    }

    func actualDailyAverageCurrentMonth() -> Double? {
        let cal = Calendar.app
        if let earliest = dailyEntries.map({ $0.createdAt }).min(),
           let threeMonthsAgo = cal.date(byAdding: .month, value: -3, to: now),
           earliest <= threeMonthsAgo {
            let current = actualMonthlyExpense(for: now)
            let day = Double(cal.component(.day, from: now))
            if day > 0 && current > 0 { return current / day }
        }
        return nil
    }

    // updateRates() — без изменений
}
// MARK: - Advisor prompt (датасводка + названия долгов/целей)
import Foundation

extension AppState {

    /// Формат валюты с учётом настроек и базовой валюты
    private func fm(_ value: Double, currency: Currency? = nil) -> String {
        formatMoney(value, currency: currency) // уже реализовано в AppState
    }

    /// Чтение значения по имени поля (безопасно для любых моделей через Mirror)
    private func mirrorValue<T>(_ any: Any, keys: [String], as type: T.Type = T.self) -> T? {
        let m = Mirror(reflecting: any)
        for child in m.children {
            if let label = child.label, keys.contains(label),
               let v = child.value as? T {
                return v
            }
        }
        return nil
    }

    /// Строка для одного долга: "• Кредит Альфа: остаток …, ставка …%, мин. платёж …, срок … мес."
    private func debtLine(_ d: Debt) -> String {
        let name = mirrorValue(d, keys: ["name", "title"], as: String.self) ?? "Долг"
        let principal = mirrorValue(d, keys: ["principal", "balance", "remaining", "outstanding", "amount"], as: Double.self)
        let apr       = mirrorValue(d, keys: ["apr", "rate", "interestRate", "annualRatePercent"], as: Double.self)
        let minPay    = mirrorValue(d, keys: ["obligatoryMonthlyPayment", "monthlyPayment", "minPayment"], as: Double.self)
        let months    = mirrorValue(d, keys: ["termMonths", "monthsLeft", "months", "term"], as: Int.self)
        let cur       = mirrorValue(d, keys: ["currency"], as: Currency.self)

        var parts: [String] = []
        if let principal { parts.append("остаток \(fm(principal, currency: cur))") }
        if let apr       { parts.append("ставка \(String(format: "%.2f", apr))%") }
        if let minPay    { parts.append("мин. платёж \(fm(minPay, currency: cur))") }
        if let months    { parts.append("срок \(months) мес.") }

        return "• \(name)" + (parts.isEmpty ? "" : ": " + parts.joined(separator: ", "))
    }

    /// Строка для одной цели: "• Резерв: цель …, накоплено …, дедлайн …"
    private func goalLine(_ g: Goal) -> String {
        let name = mirrorValue(g, keys: ["name", "title"], as: String.self) ?? "Цель"
        let target = mirrorValue(g, keys: ["targetAmount", "goalAmount", "target", "amount"], as: Double.self)
        let saved  = mirrorValue(g, keys: ["saved", "current", "progress", "accumulated", "balance"], as: Double.self)
        let cur    = mirrorValue(g, keys: ["currency"], as: Currency.self)
        let dl: Date? = mirrorValue(g, keys: ["deadline", "dueDate", "targetDate", "date"], as: Date.self)

        var parts: [String] = []
        if let target { parts.append("цель \(fm(target, currency: cur))") }
        if let saved, saved > 0 { parts.append("накоплено \(fm(saved, currency: cur))") }
        if let dl {
            let df = DateFormatter(); df.dateFormat = "dd.MM.yyyy"
            parts.append("дедлайн \(df.string(from: dl))")
        }

        return "• \(name)" + (parts.isEmpty ? "" : ": " + parts.joined(separator: ", "))
    }

    /// Системный промпт для советника: доходы/расходы + перечень долгов и целей с названиями.
    @MainActor
    func advisorSystemPrompt() -> String {
        let month = Date()

        // Итоги из твоих существующих методов:
        let incomeM = totalNormalizedMonthlyRecurringIncome(for: month)
        let expenseM = totalNormalizedMonthlyRecurringExpense(for: month) // включает мин.платежи по долгам
        let minPays = debts.reduce(into: 0.0) { acc, d in
            acc += mirrorValue(d, keys: ["obligatoryMonthlyPayment", "monthlyPayment", "minPayment"], as: Double.self) ?? 0
        }

        var lines: [String] = []

        lines.append("""
        Ты — финансовый советник в приложении FinMind. Отвечай только по теме личных финансов (бюджет, подушка, долги, цели, страхование, налоги/вычеты в общем виде).
        Говори кратко и по делу, прямо по данным пользователя, с понятными числами и формулами там, где нужно.
        """)

        lines.append("Сводка (месяц): доходы ≈ \(fm(incomeM)), расходы (вкл. мин.платежи по долгам) ≈ \(fm(expenseM)), мин.платежи по долгам ≈ \(fm(minPays)).")

        if debts.isEmpty {
            lines.append("Долги: отсутствуют.")
        } else {
            lines.append("Долги:")
            debts.forEach { lines.append(debtLine($0)) }
        }

        if goals.isEmpty {
            lines.append("Цели: отсутствуют.")
        } else {
            lines.append("Цели:")
            goals.forEach { lines.append(goalLine($0)) }
        }

        lines.append("""
        Если данных для точного расчёта по долгу/цели не хватает — коротко уточни недостающее (сумма, ставка годовая %, срок, дедлайн и т. п.) и сразу рассчитай.
        """)
        return lines.joined(separator: "\n")
    }
}
