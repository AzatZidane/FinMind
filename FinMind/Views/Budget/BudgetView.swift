import SwiftUI

struct BudgetView: View {
    @EnvironmentObject var app: AppState

    private enum SheetType: Identifiable { case income, expense, debt, goal; var id: Int { hashValue } }
    @State private var activeSheet: SheetType?

    // Текущий месяц — для сводки
    private var month: Date {
        let cal = Calendar.current
        return cal.date(from: cal.dateComponents([.year, .month], from: Date()))!
    }

    private var totalIncomeBase: Double {
        monthlyIncomeBase(for: month)
    }
    private var totalExpenseBase: Double {
        monthlyExpenseBase(for: month)
    }
    private var netBase: Double { totalIncomeBase - totalExpenseBase }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                summaryCard

                List {
                    incomesSection
                    expensesSection
                    debtsSection
                    goalsSection

                    if app.incomes.isEmpty && app.expenses.isEmpty && app.debts.isEmpty && app.goals.isEmpty {
                        Section { Text("Пока нет данных").foregroundStyle(.secondary) }
                    }
                }
            }
            .padding(.top, 8)
            .navigationTitle("Бюджет")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { EditButton() }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Добавить доход")  { activeSheet = .income }
                        Button("Добавить расход") { activeSheet = .expense }
                        Button("Добавить долг")   { activeSheet = .debt }
                        Button("Добавить цель")   { activeSheet = .goal }
                    } label: { Label("Добавить", systemImage: "plus") }
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .income:  AddIncomeView().environmentObject(app)
                case .expense: AddExpenseView().environmentObject(app)
                case .debt:    AddDebtView().environmentObject(app)
                case .goal:    AddGoalView().environmentObject(app)
                }
            }
        }
    }

    // MARK: - Итоги (месяц)
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Доходы (мес.)")
                Spacer()
                Text(app.formatMoney(totalIncomeBase, currency: app.baseCurrency))
                    .font(.headline.monospacedDigit())
            }
            HStack {
                Text("Расходы (мес.)")
                Spacer()
                Text(app.formatMoney(totalExpenseBase, currency: app.baseCurrency))
                    .font(.headline.monospacedDigit())
            }
            Divider()
            HStack {
                Text("Итог").fontWeight(.semibold)
                Spacer()
                Text(app.formatMoney(netBase, currency: app.baseCurrency))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(netBase >= 0 ? .green : .red)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.08)))
        .padding(.horizontal, 16)
    }

    // MARK: - Секции
    private var incomesSection: some View {
        Group {
            if !app.incomes.isEmpty {
                Section("Доходы") {
                    ForEach(app.incomes) { inc in
                        incomeRow(inc)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) { app.removeIncome(inc) } label: {
                                    Label("Удалить", systemImage: "trash")
                                }
                            }
                    }
                    .onDelete { offsets in app.incomes.remove(atOffsets: offsets) }
                }
            }
        }
    }

    private var expensesSection: some View {
        Group {
            if !app.expenses.isEmpty {
                Section("Расходы") {
                    ForEach(app.expenses) { exp in
                        expenseRow(exp)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) { app.removeExpense(exp) } label: {
                                    Label("Удалить", systemImage: "trash")
                                }
                            }
                    }
                    .onDelete { offsets in app.expenses.remove(atOffsets: offsets) }
                }
            }
        }
    }

    private var debtsSection: some View {
        Group {
            if !app.debts.isEmpty {
                Section("Долги") {
                    ForEach(app.debts) { d in
                        debtRow(d)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) { app.removeDebt(d) } label: {
                                    Label("Удалить", systemImage: "trash")
                                }
                            }
                    }
                    .onDelete { offsets in app.debts.remove(atOffsets: offsets) }
                }
            }
        }
    }

    private var goalsSection: some View {
        Group {
            if !app.goals.isEmpty {
                Section("Цели") {
                    ForEach(app.goals) { g in
                        goalRow(g)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) { app.removeGoal(g) } label: {
                                    Label("Удалить", systemImage: "trash")
                                }
                            }
                    }
                    .onDelete { offsets in app.goals.remove(atOffsets: offsets) }
                }
            }
        }
    }

    // MARK: - Строки
    @ViewBuilder
    private func incomeRow(_ inc: Income) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(inc.name)
                Text(kindText(inc.kind))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(app.formatMoney(inc.amount, currency: inc.currency))
                .font(.headline.monospacedDigit())
        }
    }

    @ViewBuilder
    private func expenseRow(_ exp: Expense) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(exp.name)
                Text(kindText(exp.kind))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(app.formatMoney(exp.amount, currency: exp.currency))
                .font(.headline.monospacedDigit())
        }
    }

    @ViewBuilder
    private func debtRow(_ d: Debt) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(d.name)
                Text("ежемесячный платёж").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(app.formatMoney(d.obligatoryMonthlyPayment, currency: d.currency))
                .font(.headline.monospacedDigit())
        }
    }

    @ViewBuilder
    private func goalRow(_ g: Goal) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(g.name)
                Text(g.deadline.map {
                    $0.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted))
                } ?? "Без срока")
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
            Spacer()
            Text(app.formatMoney(g.targetAmount, currency: g.currency))
                .font(.headline.monospacedDigit())
        }
    }

    // MARK: - Вспомогательные

    private func kindText(_ k: IncomeKind) -> String {
        switch k {
        case .recurring(let r): return r.localized
        case .oneOff(let d, _): return "Разовый" + (", " + d.formatted(.dateTime.day().month().year()))
        }
    }

    private func kindText(_ k: ExpenseKind) -> String {
        switch k {
        case .recurring(let r): return r.localized
        case .oneOff(let d, _):
            if let d { return "Разовый, " + d.formatted(.dateTime.day().month().year()) }
            else { return "Разовый" }
        }
    }

    private func monthlyIncomeBase(for month: Date) -> Double {
        let rec = app.totalNormalizedMonthlyRecurringIncome(for: month)
        let cal = Calendar.current
        let oneOff: Decimal = app.incomes.reduce(0) { acc, i in
            guard case .oneOff(let d, _) = i.kind,
                  cal.isDate(d, equalTo: month, toGranularity: .month)
            else { return acc }
            return acc + app.toBase(Decimal(i.amount), from: i.currency)
        }
        return rec + NSDecimalNumber(decimal: oneOff).doubleValue
    }

    private func monthlyExpenseBase(for month: Date) -> Double {
        var total = app.plannedMonthlyExpense(for: month) // рекуррентные + долги + запланированные записи
        let cal = Calendar.current
        let oneOff: Decimal = app.expenses.reduce(0) { acc, e in
            guard case .oneOff(let d, _) = e.kind,
                  let d, cal.isDate(d, equalTo: month, toGranularity: .month)
            else { return acc }
            return acc + app.toBase(Decimal(e.amount), from: e.currency)
        }
        total += NSDecimalNumber(decimal: oneOff).doubleValue
        return total
    }
}

#Preview {
    BudgetView().environmentObject(AppState())
}
