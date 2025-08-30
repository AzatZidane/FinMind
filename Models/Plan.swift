// Models/Plan.swift
import Foundation

// Какую долю СДП куда отправляем
enum AllocationKind: String, Codable, Hashable, CaseIterable {
    case emergency = "Подушка"
    case debts = "Долги"
    case goals = "Цели"
}

struct Allocation: Identifiable, Codable, Hashable {
    let id = UUID()
    let kind: AllocationKind
    let amount: Double
    let rationale: String?
}

struct PlanResult: Codable, Hashable {
    let sdp: Double                // Свободный денежный поток (в мес)
    let allocations: [Allocation]  // Распределение СДП
    let notes: [String]            // Служебные заметки
}

enum PlanEngine {
    static func makePlan(app: AppState, month: Date = Date()) -> PlanResult {
        // Доходы/расходы считаем из AppState (нормализованные ежемесячные)
        let income = app.totalNormalizedMonthlyRecurringIncome(for: month)
        let expense = app.totalNormalizedMonthlyRecurringExpense(for: month)
        let sdp = max(0, income - expense)

        // Базовые доли по ТЗ: подушка 40%, долги 40%, цели 20%
        let toEmergency = sdp * 0.40
        let toDebts     = sdp * 0.40
        let toGoals     = sdp * 0.20

        let allocations: [Allocation] = [
            Allocation(kind: .emergency, amount: toEmergency, rationale: "40% от СДП"),
            Allocation(kind: .debts,     amount: toDebts,     rationale: "40% от СДП (стратегия «лавина» — далее)"),
            Allocation(kind: .goals,     amount: toGoals,     rationale: "20% от СДП, распределение по приоритетам/срокам")
        ]

        let notes = [
            "Доходы (нормализ.) в мес: \(income.moneyString)",
            "Расходы (план) в мес: \(expense.moneyString)",
            "СДП: \(sdp.moneyString)"
        ]

        return PlanResult(sdp: sdp, allocations: allocations, notes: notes)
    }
}
