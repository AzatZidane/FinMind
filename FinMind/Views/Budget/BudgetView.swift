import SwiftUI

struct BudgetView: View {
    @EnvironmentObject var app: AppState
    
    @State private var showIncomes = true
    @State private var showExpenses = true
    @State private var showDebts = true
    @State private var showGoals = true
    
    @State private var presentAddIncome = false
    @State private var presentAddExpense = false
    @State private var presentAddDebt = false
    @State private var presentAddGoal = false
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: Доходы
                Section {
                    if showIncomes {
                        if app.incomes.isEmpty {
                            Text("Нет доходов — добавьте первый")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(app.incomes) { inc in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(inc.name).font(.headline)
                                        switch inc.kind {
                                        case let .recurring(periodicity, start, end, _):
                                            Text("\(periodicity.rawValue). С \(start.formatted(date: .abbreviated, time: .omitted))\(end != nil ? " по \(end!.formatted(date: .abbreviated, time: .omitted))" : "")")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        case let .oneOff(date, planned):
                                            Text("Разовый • \(planned ? "План" : "Факт") • \(date.formatted(date: .abbreviated, time: .omitted))")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Text(inc.amount.moneyString).font(.body.monospacedDigit())
                                }
                                .swipeActions {
                                    Button(role: .destructive) {
                                        app.removeIncome(inc)
                                    } label: {
                                        Label("Удалить", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        
                        // Итого годовой доход
                        HStack {
                            Text("Итого годовой доход").foregroundStyle(.secondary)
                            Spacer()
                            Text(app.totalAnnualIncome().moneyString).font(.body.monospacedDigit())
                        }
                    }
                } header: {
                    header("Доходы",
                           isOpen: $showIncomes,
                           onAdd: { presentAddIncome = true })
                }
                
                // MARK: Расходы
                Section {
                    if showExpenses {
                        // Итоги в шапке секции (как в ТЗ)
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Общий расход в год")
                                Spacer()
                                Text(app.annualExpense().moneyString)
                            }
                            HStack {
                                Text("Общий расход в месяц")
                                Spacer()
                                Text(app.plannedMonthlyExpense().moneyString)
                            }
                            HStack {
                                Text("Плановый средний/день (текущий месяц)")
                                Spacer()
                                Text(app.plannedDailyAverageCurrentMonth().moneyString)
                            }
                            if let fact = app.actualDailyAverageCurrentMonth() {
                                HStack {
                                    Text("Фактический средний/день (текущий месяц)")
                                    Spacer()
                                    Text(fact.moneyString)
                                }
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        
                        if app.expenses.isEmpty && app.debts.isEmpty {
                            Text("Нет расходов — добавьте статью или долг")
                                .foregroundStyle(.secondary)
                        } else {
                            // Регулярные расходы (список)
                            ForEach(app.expenses) { exp in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(exp.name).font(.headline)
                                        switch exp.kind {
                                        case let .recurring(periodicity, start, end):
                                            Text("\(exp.category.rawValue). \(periodicity.rawValue). С \(start.formatted(date: .abbreviated, time: .omitted))\(end != nil ? " по \(end!.formatted(date: .abbreviated, time: .omitted))" : "")")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        case let .oneOff(date, planned):
                                            Text("\(exp.category.rawValue). Разовый • \(planned ? "План" : "Факт") • \(date.formatted(date: .abbreviated, time: .omitted))")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Text(exp.amount.moneyString).font(.body.monospacedDigit())
                                }
                                .swipeActions {
                                    Button(role: .destructive) {
                                        app.removeExpense(exp)
                                    } label: {
                                        Label("Удалить", systemImage: "trash")
                                    }
                                }
                            }
                            
                            // Ежемесячные обязательные платежи по долгам (как строка расходов)
                            ForEach(app.debts) { d in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Платёж по долгу: \(d.name)")
                                            .font(.headline)
                                        Text("Обязательный ежемесячный платёж")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(d.obligatoryMonthlyPayment.moneyString).font(.body.monospacedDigit())
                                }
                            }
                        }
                    }
                } header: {
                    header("Расходы",
                           isOpen: $showExpenses,
                           onAdd: { presentAddExpense = true })
                }
                
                // MARK: Долги
                Section {
                    if showDebts {
                        if app.debts.isEmpty {
                            Text("Долгов нет — добавьте, если есть кредиты/карты")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(app.debts) { d in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(d.name).font(.headline)
                                        Text("Ежемесячно: \(d.obligatoryMonthlyPayment.moneyString)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                                .swipeActions {
                                    Button(role: .destructive) {
                                        app.removeDebt(d)
                                    } label: {
                                        Label("Удалить", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    header("Долги",
                           isOpen: $showDebts,
                           onAdd: { presentAddDebt = true })
                }
                
                // MARK: Цели
                Section {
                    if showGoals {
                        if app.goals.isEmpty {
                            Text("Целей пока нет — добавьте первые")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(app.goals) { g in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(g.name).font(.headline)
                                        Text("Цель: \(g.targetAmount.moneyString) • До: \(g.deadline.formatted(date: .abbreviated, time: .omitted)) • Приоритет: \(g.priority)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                                .swipeActions {
                                    Button(role: .destructive) {
                                        app.removeGoal(g)
                                    } label: {
                                        Label("Удалить", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    header("Цели",
                           isOpen: $showGoals,
                           onAdd: { presentAddGoal = true })
                }
            }
            .navigationTitle("Данные")
            .toolbar {
                NavigationLink("Календарь") {
                    CalendarListView()
                }
            }
            .sheet(isPresented: $presentAddIncome) {
                AddIncomeView()
                    .environmentObject(app)
            }
            .sheet(isPresented: $presentAddExpense) {
                AddExpenseView()
                    .environmentObject(app)
            }
            .sheet(isPresented: $presentAddDebt) {
                AddDebtView()
                    .environmentObject(app)
            }
            .sheet(isPresented: $presentAddGoal) {
                AddGoalView()
                    .environmentObject(app)
            }
        }
    }
    
    // Header builder with chevron + add button
    @ViewBuilder
    private func header(_ title: String, isOpen: Binding<Bool>, onAdd: @escaping () -> Void) -> some View {
        HStack {
            Text(title).font(.headline)
            Spacer()
            Button {
                isOpen.wrappedValue.toggle()
            } label: {
                Image(systemName: isOpen.wrappedValue ? "chevron.down" : "chevron.right")
            }
            Button(action: onAdd) {
                Image(systemName: "plus.circle")
            }
        }
    }
}

#Preview {
    BudgetView().environmentObject(AppState())
}
