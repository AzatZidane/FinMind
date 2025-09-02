import Foundation

/// Совместимость со старым API AddDebtView:
/// Debt(name: ..., input: .monthlyPayment / .loan)
enum DebtInput {
    case monthlyPayment(amount: Double, isMinimum: Bool)
    case loan(principal: Double, apr: Double, termMonths: Int, graceMonths: Int?, minPayment: Double?)
}

extension Debt {
    /// Создаёт текущую модель долга (title + obligatoryMonthlyPayment + currency)
    /// из старого формата конструктора, который использует AddDebtView.
    init(name: String, input: DebtInput, currency: Currency = .rub) {
        switch input {
        case .monthlyPayment(let amount, _):
            // Ежемесячный платёж задаётся прямо
            self = Debt(id: UUID(), title: name, obligatoryMonthlyPayment: amount, currency: currency)

        case .loan(let principal, let apr, let termMonths, _, let minPayment):
            // Расчёт аннуитетного платежа (если minPayment не задан)
            let r = apr / 100.0 / 12.0              // месячная ставка
            let n = Double(termMonths)
            let computed: Double
            if let minPayment, minPayment > 0 {
                computed = minPayment
            } else if r == 0 {
                computed = principal / n
            } else {
                computed = principal * r / (1.0 - pow(1.0 + r, -n))
            }
            self = Debt(id: UUID(), title: name, obligatoryMonthlyPayment: computed, currency: currency)
        }
    }
}
