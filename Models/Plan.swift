import Foundation

struct Plan: Identifiable, Codable, Hashable {
    var id = UUID()
    var incomes: [Income]
    var expenses: [Expense]
    var goals: [Goal]
    var currencyCode: String

    var monthlyIncome: Double { incomes.reduce(0) { $0 + $1.monthlyAmount } }
    var monthlySpending: Double { expenses.reduce(0) { $0 + $1.monthlyAmount } }

    init(incomes: [Income] = [], expenses: [Expense] = [], goals: [Goal] = [], currencyCode: String = Locale.current.currency?.identifier ?? "USD") {
        self.incomes = incomes
        self.expenses = expenses
        self.goals = goals
        self.currencyCode = currencyCode
    }
}

extension Plan {
    init(profile: UserProfile) { self.init(incomes: profile.incomes, expenses: profile.expenses, goals: profile.goals, currencyCode: profile.currencyCode) }
    init(userProfile: UserProfile) { self.init(profile: userProfile) }
    init(from userProfile: UserProfile) { self.init(profile: userProfile) }
    static let sample = Plan(profile: .sample)
}
