import Foundation

extension AppState {
    func updateIncome(_ income: Income) {
        if let i = incomes.firstIndex(where: { $0.id == income.id }) { incomes[i] = income }
    }
    func updateExpense(_ expense: Expense) {
        if let i = expenses.firstIndex(where: { $0.id == expense.id }) { expenses[i] = expense }
    }
    func updateGoal(_ goal: Goal) {
        if let i = goals.firstIndex(where: { $0.id == goal.id }) { goals[i] = goal }
    }
    func updateDebt(_ debt: Debt) {
        if let i = debts.firstIndex(where: { $0.id == debt.id }) { debts[i] = debt }
    }
}
