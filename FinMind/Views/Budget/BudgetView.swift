import SwiftUI

struct BudgetView: View {
    @EnvironmentObject var app: AppState

    private enum SheetType: Identifiable { case income, expense, debt, goal; var id: Int { hashValue } }
    @State private var activeSheet: SheetType?

    // Агрегаты
    private var totalIncome: Double { app.incomes.reduce(0) { $0 + $1.amount } }
    private var totalExpense: Double { app.expenses.reduce(0) { $0 + $1.amount } }
    private var net: Double { totalIncome - totalExpense }

    // Источники для списков
    private var incomesList: [Income] { app.incomes }
    private var expensesList: [Expense] { app.expenses }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                summaryCard

                List {
                    incomesSection
                    expensesSection

                    if incomesList.isEmpty && expensesList.isEmpty {
                        Section { Text("Пока нет данных").foregroundStyle(.secondary) }
                    }
                }
            }
            .padding(.top, 8)
            .navigationTitle("Бюджет")
            .toolbar {
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

    // MARK: - Итоги
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text("Доходы");  Spacer(); Text(totalIncome.asMoney).font(.headline.monospacedDigit()) }
            HStack { Text("Расходы"); Spacer(); Text(totalExpense.asMoney).font(.headline.monospacedDigit()) }
            Divider()
            HStack {
                Text("Итог").fontWeight(.semibold)
                Spacer()
                Text(net.asMoney)
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(net >= 0 ? .green : .red)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.08)))
        .padding(.horizontal, 16)
    }

    // MARK: - Секции
    private var incomesSection: some View {
        Group {
            if !incomesList.isEmpty {
                Section {
                    ForEach(Array(incomesList.enumerated()), id: \.offset) { _, inc in incomeRow(inc) }
                    .onDelete { offsets in
                        app.incomes.remove(atOffsets: offsets)   // свайп-влево — удалить
                    }
                } header: { Text("Доходы") }
            }
        }
    }

    private var expensesSection: some View {
        Group {
            if !expensesList.isEmpty {
                Section {
                    ForEach(Array(expensesList.enumerated()), id: \.offset) { _, exp in expenseRow(exp) }
                    .onDelete { offsets in
                        app.expenses.remove(atOffsets: offsets)
                    }
                } header: { Text("Расходы") }
            }
        }
    }

    // MARK: - Строки
    @ViewBuilder
    private func incomeRow(_ inc: Income) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(inc.name)
                Text("доход").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(inc.amount.asMoney).font(.headline.monospacedDigit())
        }
    }

    @ViewBuilder
    private func expenseRow(_ exp: Expense) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(exp.name)
                Text("расход").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(exp.amount.asMoney).font(.headline.monospacedDigit())
        }
    }
}

#Preview { BudgetView().environmentObject(AppState()) }
