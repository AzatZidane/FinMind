import Foundation

/// Старый формат ввода долгов
enum DebtInput {
    case monthlyPayment(amount: Double, isMinimum: Bool)
    case loan(principal: Double, apr: Double, termMonths: Int, graceMonths: Int?, minPayment: Double?)
}

extension Debt {
    /// Совместимый инициализатор из старого API
    init(name: String, input: DebtInput, currency: Currency = .rub) {
        switch input {
        case .monthlyPayment(let amount, _):
            self = Debt(id: UUID(), title: name, obligatoryMonthlyPayment: amount, currency: currency)

        case .loan(let principal, let apr, let termMonths, _, let minPayment):
            // Аннуитетный платёж, если minPayment не задан
            let r = apr / 100.0 / 12.0
            let n = Double(termMonths)
            let payment: Double
            if let m = minPayment, m > 0 {
                payment = m
            } else if r == 0 {
                payment = principal / n
            } else {
                payment = principal * r / (1.0 - pow(1.0 + r, -n))
            }
            self = Debt(id: UUID(), title: name, obligatoryMonthlyPayment: payment, currency: currency)
        }
    }

    /// Совместимое свойство для чтения `debt.input` в старых вью
    var input: DebtInput {
        .monthlyPayment(amount: obligatoryMonthlyPayment, isMinimum: true)
    }
}
