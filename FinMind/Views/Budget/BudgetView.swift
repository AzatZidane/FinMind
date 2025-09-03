import SwiftUI

struct BudgetView: View {
    @EnvironmentObject var app: AppState

    // Листы добавления сущностей
    private enum SheetType: Identifiable { case income, expense, debt, goal; var id: Int { hashValue } }
    @State private var activeSheet: SheetType?

    // Итоги в базовой валюте
    private var totalIncomeBase: Double {
        let sum: Decimal = app.incomes.reduce(0) { acc, inc in
            acc + app.toBase(Decimal(inc.amount), from: inc.currency)
        }
        return NSDecimalNumber(decimal: sum).doubleValue
    }

    private var totalExpenseBase: Double {
        let sum: Decimal = app.expenses.reduce(0) { acc, exp in
            acc + app.toBase(Decimal(exp.amount), from: exp.currency)
        }
        return NSDecimalNumber(decimal: sum).doubleValue
    }

    private var netBase: Double { totalIncomeBase - totalExpenseBase }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                summaryCard

                List {
                    incomesSection
                    expensesSection

                    if app.incomes.isEmpty && app.expenses.isEmpty {
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

    // MARK: - Итоговая карточка
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Доходы")
                Spacer()
                Text(app.formatMoney(totalIncomeBase, currency: app.baseCurrency))
                    .font(.headline.monospacedDigit())
            }
            HStack {
                Text("Расходы")
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
                                Button(role: .destructive) {
                                    app.removeIncome(inc)
                                } label: {
                                    Label("Удалить", systemImage: "trash")
                                }
                            }
                    }
                    .onDelete { offsets in
                        app.incomes.remove(atOffsets: offsets) // режим «Править»
                    }
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
                                Button(role: .destructive) {
                                    app.removeExpense(exp)
                                } label: {
                                    Label("Удалить", systemImage: "trash")
                                }
                            }
                    }
                    .onDelete { offsets in
                        app.expenses.remove(atOffsets: offsets) // режим «Править»
                    }
                }
            }
        }
    }

    // MARK: - Строки
    @ViewBuilder
    private func incomeRow(_ inc: Income) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(inc.name) // NameCompat -> title
                Text("доход").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(app.formatMoney(inc.amount, currency: inc.currency))
                .font(.headline.monospacedDigit())
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func expenseRow(_ exp: Expense) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(exp.name)
                Text("расход").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(app.formatMoney(exp.amount, currency: exp.currency))
                .font(.headline.monospacedDigit())
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    BudgetView().environmentObject(AppState())
}
