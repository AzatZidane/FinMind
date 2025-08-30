import Foundation

struct UserProfile: Identifiable, Codable, Hashable {
    var id = UUID()
    var incomes: [Income] = []
    var expenses: [Expense] = []
    var goals: [Goal] = []
    var currencyCode: String = Locale.current.currency?.identifier ?? "USD"

    static let sample = UserProfile(
        incomes: [Income(name: "Зарплата", amount: 1500)],
        expenses: [Expense(name: "Аренда", amount: 600)],
        goals: [Goal(name: "Подушка", targetAmount: 3000)]
    )
}
