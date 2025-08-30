import Foundation
import Combine

final class AppState: ObservableObject, Codable {
    // Data
    @Published var incomes: [Income]
    @Published var expenses: [Expense]
    @Published var debts: [Debt]
    @Published var goals: [Goal]
    @Published var dailyEntries: [DailyEntry]
    @Published var firstUseAt: Date
    
    enum CodingKeys: String, CodingKey {
        case incomes, expenses, debts, goals, dailyEntries, firstUseAt
    }
    
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
    
    // MARK: Codable
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
    
    // MARK: - Persistence
    private var cancellables = Set<AnyCancellable>()
    
    func startAutoSave() {
        // Save on any change with small debounce
        Publishers.MergeMany(
            $incomes.map { _ in () },
            $expenses.map { _ in () },
            $debts.map { _ in () },
            $goals.map { _ in () },
            $dailyEntries.map { _ in () }
        )
        .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
        .sink { [weak self] _ in
            guard let self else { return }
            try? Persistence.shared.save(self)
        }
        .store(in: &cancellables)
    }
    
    // MARK: - Mutations
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
    
    // MARK: - Metrics (current month/year)
    private var now: Date { Date() }
    
    func totalNormalizedMonthlyRecurringIncome(for month: Date = Date()) -> Double {
        incomes.reduce(0) { sum, inc in
            sum + inc.normalizedMonthlyAmount(for: month)
        }
    }
    
    func totalRecurringAnnualIncome(for year: Int = Calendar.app.component(.year, from: Date())) -> Double {
        // Sum for each month based on active recurring incomes
        var total: Double = 0
        let cal = Calendar.app
        for m in 1...12 {
            var comps = DateComponents()
            comps.year = year
            comps.month = m
            comps.day = 1
            let month = cal.date(from: comps)!
            total += totalNormalizedMonthlyRecurringIncome(for: month)
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
    
    /// As per spec: annualIncome = sum of normalized monthly recurring across months + one-off income within the selected period (year)
    func totalAnnualIncome(for year: Int = Calendar.app.component(.year, from: Date())) -> Double {
        return totalRecurringAnnualIncome(for: year) + totalOneOffIncome(for: year)
    }
    
    // Expenses
    func totalNormalizedMonthlyRecurringExpense(for month: Date = Date()) -> Double {
        var base = expenses.reduce(0) { $0 + $1.normalizedMonthlyAmount(for: month) }
        // Include obligatory monthly payments from debts
        base += debts.reduce(0) { $0 + $1.obligatoryMonthlyPayment }
        return base
    }
    
    func plannedMonthlyExpense(for month: Date = Date()) -> Double {
        let recurring = totalNormalizedMonthlyRecurringExpense(for: month)
        // planned one-offs from calendar for given month
        let plannedExtras = dailyEntries
            .filter { $0.type == .expense && $0.planned && $0.date.isSameMonth(as: month) }
            .reduce(0) { $0 + $1.amount }
        return recurring + plannedExtras
    }
    
    func actualMonthlyExpense(for month: Date = Date()) -> Double {
        return dailyEntries
            .filter { $0.type == .expense && !$0.planned && $0.date.isSameMonth(as: month) }
            .reduce(0) { $0 + $1.amount }
    }
    
    func annualExpense(for year: Int = Calendar.app.component(.year, from: Date())) -> Double {
        var total: Double = 0
        let cal = Calendar.app
        for m in 1...12 {
            var comps = DateComponents(); comps.year = year; comps.month = m; comps.day = 1
            let month = cal.date(from: comps)!
            total += plannedMonthlyExpense(for: month) // use planned as "baseline"
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
        // available if user is in system ≥ 3 months and there is fact data
        let cal = Calendar.app
        if let earliest = (dailyEntries.map { $0.createdAt }.min()), let threeMonthsAgo = cal.date(byAdding: .month, value: -3, to: now), earliest <= threeMonthsAgo {
            let currentMonthSum = actualMonthlyExpense(for: now)
            let day = Double(cal.component(.day, from: now))
            if day > 0 && currentMonthSum > 0 {
                return currentMonthSum / day
            }
        }
        return nil
    }
}
