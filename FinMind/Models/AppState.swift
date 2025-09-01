import Foundation
import Combine

extension AppState {
    /// Мутирует текущий объект, подменяя его данные загруженными с диска (если есть).
    func loadFromDiskIfAvailable() {
        guard let loaded = try? Persistence.shared.load() else { return }
        // перекачиваем значения в опубликованные свойства
        incomes = loaded.incomes
        expenses = loaded.expenses
        debts = loaded.debts
        goals = loaded.goals
        dailyEntries = loaded.dailyEntries
        firstUseAt = loaded.firstUseAt
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

    enum CodingKeys: String, CodingKey {
        case incomes, expenses, debts, goals, dailyEntries, firstUseAt
    }

    // MARK: - Инициализация
    init(incomes: [Income] = [],
         expenses: [Expense] = [],
         debts: [Debt] = [],
         goals: [Goal] = [],
         dailyEntries: [DailyEntry] = [],
         firstUseAt: Date = Date()) {
        self.incomes = incomes
        self.expenses = expenses
        self.debts = debts
        self.goals = goals
        self.dailyEntries = dailyEntries
        self.firstUseAt = firstUseAt
    }

    // MARK: - Codable
    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.incomes = try c.decodeIfPresent([Income].self, forKey: .incomes) ?? []
        self.expenses = try c.decodeIfPresent([Expense].self, forKey: .expenses) ?? []
        self.debts = try c.decodeIfPresent([Debt].self, forKey: .debts) ?? []
        self.goals = try c.decodeIfPresent([Goal].self, forKey: .goals) ?? []
        self.dailyEntries = try c.decodeIfPresent([DailyEntry].self, forKey: .dailyEntries) ?? []
        self.firstUseAt = try c.decodeIfPresent(Date.self, forKey: .firstUseAt) ?? Date()
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(incomes, forKey: .incomes)
        try c.encode(expenses, forKey: .expenses)
        try c.encode(debts, forKey: .debts)
        try c.encode(goals, forKey: .goals)
        try c.encode(dailyEntries, forKey: .dailyEntries)
        try c.encode(firstUseAt, forKey: .firstUseAt)
    }

    // MARK: - Автосохранение
    private var cancellables = Set<AnyCancellable>()

    /// Запускаем автосохранение состояния при любых изменениях массивов
    func startAutoSave() {
        let updates: [AnyPublisher<Void, Never>] = [
            $incomes.map { _ in () }.eraseToAnyPublisher(),
            $expenses.map { _ in () }.eraseToAnyPublisher(),
            $debts.map { _ in () }.eraseToAnyPublisher(),
            $goals.map { _ in () }.eraseToAnyPublisher(),
            $dailyEntries.map { _ in () }.eraseToAnyPublisher()
        ]

        Publishers.MergeMany(updates)
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                do {
                    try Persistence.shared.save(self) // save может кидать — оборачиваем в do/try/catch
                } catch {
                    print("Persistence save error:", error.localizedDescription)
                }
            }
            .store(in: &cancellables)
    }

    /// Ручное сохранение (используется после импорта/восстановления)
    func forceSave() {
        do {
            try Persistence.shared.save(self)
        } catch {
            print("Persistence forceSave error:", error.localizedDescription)
        }
    }

    // MARK: - Мутации
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

    // MARK: - Метрики (месяц/год)
    private var now: Date { Date() }

    func totalNormalizedMonthlyRecurringIncome(for month: Date = Date()) -> Double {
        incomes.reduce(0) { $0 + $1.normalizedMonthlyAmount(for: month) }
    }

    func totalRecurringAnnualIncome(for year: Int = Calendar.app.component(.year, from: Date())) -> Double {
        var total: Double = 0
        let cal = Calendar.app
        for m in 1...12 {
            var comps = DateComponents()
            comps.year = year
            comps.month = m
            comps.day = 1
            if let month = cal.date(from: comps) {
                total += totalNormalizedMonthlyRecurringIncome(for: month)
            }
        }
        return total
    }

    func totalOneOffIncome(for year: Int = Calendar.app.component(.year, from: Date())) -> Double {
        incomes.reduce(0) { sum, inc in
            switch inc.kind {
            case .oneOff(let date, _):
                return sum + (date.yearInt() == year ? inc.amount : 0)
            default:
                return sum
            }
        }
    }

    /// Годовой доход = сумма нормированных помесячных рекуррентных + разовые в пределах года
    func totalAnnualIncome(for year: Int = Calendar.app.component(.year, from: Date())) -> Double {
        totalRecurringAnnualIncome(for: year) + totalOneOffIncome(for: year)
    }

    // Expenses
    func totalNormalizedMonthlyRecurringExpense(for month: Date = Date()) -> Double {
        var base = expenses.reduce(0) { $0 + $1.normalizedMonthlyAmount(for: month) }
        // Обязательные платежи по долгам
        base += debts.reduce(0) { $0 + $1.obligatoryMonthlyPayment }
        return base
    }

    func plannedMonthlyExpense(for month: Date = Date()) -> Double {
        let recurring = totalNormalizedMonthlyRecurringExpense(for: month)
        let plannedExtras = dailyEntries
            .filter { $0.type == .expense && $0.planned && $0.date.isSameMonth(as: month) }
            .reduce(0) { $0 + $1.amount }
        return recurring + plannedExtras
    }

    func actualMonthlyExpense(for month: Date = Date()) -> Double {
        dailyEntries
            .filter { $0.type == .expense && !$0.planned && $0.date.isSameMonth(as: month) }
            .reduce(0) { $0 + $1.amount }
    }

    func annualExpense(for year: Int = Calendar.app.component(.year, from: Date())) -> Double {
        var total: Double = 0
        let cal = Calendar.app
        for m in 1...12 {
            var comps = DateComponents(); comps.year = year; comps.month = m; comps.day = 1
            if let month = cal.date(from: comps) {
                total += plannedMonthlyExpense(for: month) // план как «база»
            }
        }
        return total
    }

    func plannedDailyAverageCurrentMonth() -> Double {
        let month = now
        let plan = plannedMonthlyExpense(for: month)
        let days = Double(month.daysInMonth())
        return days > 0 ? plan / days : 0
    }

    func actualDailyAverageCurrentMonth() -> Double? {
        // доступно, если пользователь в системе ≥ 3 месяца и есть факт-данные
        let cal = Calendar.app
        if let earliest = (dailyEntries.map { $0.createdAt }.min()),
           let threeMonthsAgo = cal.date(byAdding: .month, value: -3, to: now),
           earliest <= threeMonthsAgo {
            let currentMonthSum = actualMonthlyExpense(for: now)
            let day = Double(cal.component(.day, from: now))
            if day > 0 && currentMonthSum > 0 {
                return currentMonthSum / day
            }
        }
        return nil
    }
}
