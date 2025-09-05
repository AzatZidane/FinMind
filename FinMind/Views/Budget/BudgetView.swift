import SwiftUI

struct BudgetView: View {
    @EnvironmentObject var app: AppState

    // Курсы
    @State private var rates: RatesSnapshot?
    @State private var isLoadingRates = false
    @State private var ratesError: String?

    // Листы «Добавить»
    private enum SheetType: Identifiable { case income, expense, debt, goal; var id: Int { hashValue } }
    @State private var activeSheet: SheetType?

    // Листы «Редактировать»
    @State private var editingIncome: Income?
    @State private var editingExpense: Expense?

    // Текущий месяц (первый день)
    private var month: Date {
        let cal = Calendar.current
        return cal.date(from: cal.dateComponents([.year, .month], from: Date()))!
    }

    private var totalIncomeBase: Double { monthlyIncomeBase(for: month) }
    private var totalExpenseBase: Double { monthlyExpenseBase(for: month) }
    private var netBase: Double { totalIncomeBase - totalExpenseBase }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                summaryCard

                List {
                    savingsSection
                    incomesSection
                    expensesSection
                    debtsSection
                    goalsSection

                    if app.incomes.isEmpty && app.expenses.isEmpty && app.debts.isEmpty && app.goals.isEmpty {
                        Section { Text("Пока нет данных").foregroundStyle(.secondary) }
                    }
                }
                .transaction { $0.animation = nil } // немного быстрее прокрутка
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
            .onAppear {
                if rates == nil {
                    Task { await loadRates() }
                }
            }
            // Добавление
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .income:  AddIncomeView().environmentObject(app)
                case .expense: AddExpenseView().environmentObject(app)
                case .debt:    AddDebtView().environmentObject(app)
                case .goal:    AddGoalView().environmentObject(app)
                }
            }
            // Редактирование
            .sheet(item: $editingIncome) { inc in
                EditIncomeView(income: inc).environmentObject(app)
            }
            .sheet(item: $editingExpense) { exp in
                EditExpenseView(expense: exp).environmentObject(app)
            }
        }
    }

    // MARK: - Секция «Сбережения»
    private var savingsSection: some View {
        Section("Сбережения") {
            HStack {
                Text("Всего (в RUB)")
                Spacer()
                Text(formattedRUB(totalSavingsRub()))
                    .font(.headline.monospacedDigit())
            }

            if let r = rates {
                HStack {
                    Text("Курсы обновлены")
                    Spacer()
                    Text(r.updatedAt.formatted(date: .abbreviated, time: .shortened))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            if let e = ratesError {
                Text(e).foregroundStyle(.red).font(.footnote)
            }

            NavigationLink {
                EditSavingsView()
            } label: {
                Label("Редактировать сбережения", systemImage: "pencil")
            }

            Button {
                Task { await loadRates(force: true) }
            } label: {
                if isLoadingRates {
                    HStack { ProgressView(); Text("Обновляем курсы…") }
                } else {
                    Label("Обновить курсы", systemImage: "arrow.clockwise")
                }
            }
            .disabled(isLoadingRates)
        }
    }

    // MARK: - Итоговая карточка
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
                Text("Итог")
                Spacer()
                Text(app.formatMoney(netBase, currency: app.baseCurrency))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(netBase >= 0 ? .green : .red)
            }
            if let rub = rates?.usdToRub {
                Divider()
                HStack {
                    Text("Курс USD/RUB")
                    Spacer()
                    Text(formattedRUB(rub))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.08)))
        .padding(.horizontal, 16)
    }

    // MARK: - Разделы доходы/расходы/долги/цели

    private var incomesSection: some View {
        Group {
            if !app.incomes.isEmpty {
                Section("Доходы") {
                    ForEach(app.incomes) { inc in
                        incomeRow(inc)
                            .contextMenu {
                                Button { editingIncome = inc } label: {
                                    Label("Редактировать", systemImage: "pencil")
                                }
                                Button(role: .destructive) { app.removeIncome(inc) } label: {
                                    Label("Удалить", systemImage: "trash")
                                }
                            }
                            .swipeActions {
                                Button { editingIncome = inc } label: {
                                    Label("Редакт.", systemImage: "pencil")
                                }
                                .tint(.blue)
                                Button(role: .destructive) { app.removeIncome(inc) } label: {
                                    Label("Удалить", systemImage: "trash")
                                }
                            }
                    }
                    .onDelete { app.incomes.remove(atOffsets: $0) }
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
                            .contextMenu {
                                Button { editingExpense = exp } label: {
                                    Label("Редактировать", systemImage: "pencil")
                                }
                                Button(role: .destructive) { app.removeExpense(exp) } label: {
                                    Label("Удалить", systemImage: "trash")
                                }
                            }
                            .swipeActions {
                                Button { editingExpense = exp } label: {
                                    Label("Редакт.", systemImage: "pencil")
                                }
                                .tint(.blue)
                                Button(role: .destructive) { app.removeExpense(exp) } label: {
                                    Label("Удалить", systemImage: "trash")
                                }
                            }
                    }
                    .onDelete { app.expenses.remove(atOffsets: $0) }
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
                            .swipeActions {
                                Button(role: .destructive) { app.removeDebt(d) } label: {
                                    Label("Удалить", systemImage: "trash")
                                }
                            }
                    }
                    .onDelete { app.debts.remove(atOffsets: $0) }
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
                            .swipeActions {
                                Button(role: .destructive) { app.removeGoal(g) } label: {
                                    Label("Удалить", systemImage: "trash")
                                }
                            }
                    }
                    .onDelete { app.goals.remove(atOffsets: $0) }
                }
            }
        }
    }

    // MARK: - Строки
    @ViewBuilder private func incomeRow(_ inc: Income) -> some View {
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

    @ViewBuilder private func expenseRow(_ exp: Expense) -> some View {
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

    @ViewBuilder private func debtRow(_ d: Debt) -> some View {
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

    @ViewBuilder private func goalRow(_ g: Goal) -> some View {
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

    // MARK: - Helpers: подписи типов
    private func kindText(_ k: IncomeKind) -> String {
        switch k {
        case .recurring(let r): return r.localized
        case .oneOff(let d, _): return "Разовый, " + d.formatted(.dateTime.day().month().year())
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

    // MARK: - Helpers: месячные суммы в базовой валюте
    private func monthlyIncomeBase(for month: Date) -> Double {
        let rec = app.totalNormalizedMonthlyRecurringIncome(for: month)
        let cal = Calendar.current
        let oneOff: Decimal = app.incomes.reduce(0) { acc, i in
            guard case .oneOff(let d, _) = i.kind,
                  cal.isDate(d, equalTo: month, toGranularity: .month) else { return acc }
            return acc + app.toBase(Decimal(i.amount), from: i.currency)
        }
        return rec + NSDecimalNumber(decimal: oneOff).doubleValue
    }

    private func monthlyExpenseBase(for month: Date) -> Double {
        var total = app.plannedMonthlyExpense(for: month)
        let cal = Calendar.current
        let oneOff: Decimal = app.expenses.reduce(0) { acc, e in
            guard case .oneOff(let d, _) = e.kind,
                  let d, cal.isDate(d, equalTo: month, toGranularity: .month) else { return acc }
            return acc + app.toBase(Decimal(e.amount), from: e.currency)
        }
        total += NSDecimalNumber(decimal: oneOff).doubleValue
        return total
    }

    // MARK: - Сбережения: сумма в RUB (фиат + крипто)
    private func totalSavingsRub() -> Double {
        guard let r = rates else { return 0 }
        var total: Double = 0

        // ФИАТ: сумма в валюте -> RUB
        for (code, amount) in SavingsStore.shared.fiat {
            guard amount > 0 else { continue }
            let c = code.uppercased()
            if c == "RUB" {
                total += amount
            } else if c == "USD" {
                total += amount * r.usdToRub
            } else if let usdToCurr = r.fiatUSD[c], usdToCurr > 0 {
                // 1 USD = usdToCurr currency -> 1 currency = 1/usdToCurr USD
                total += amount * (r.usdToRub / usdToCurr)
            }
        }

        // КРИПТО: qty * USD * (USD->RUB)
        for (asset, qty) in SavingsStore.shared.cryptoHoldings {
            guard qty > 0, let usd = r.cryptoUsd[asset] else { continue }
            total += qty * usd * r.usdToRub
        }
        return total.isFinite ? total : 0
    }

    private func formattedRUB(_ amount: Double) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.groupingSeparator = "."
        nf.decimalSeparator = ","
        nf.minimumFractionDigits = app.fractionDigits(for: .rub)
        nf.maximumFractionDigits = app.fractionDigits(for: .rub)
        return (nf.string(from: NSNumber(value: amount)) ?? "0") + " ₽"
    }

    private func loadRates(force: Bool = false) async {
        if isLoadingRates { return }
        isLoadingRates = true
        ratesError = nil
        do {
            let codes = SavingsStore.shared.fiatCodesToFetch()
            let snap = try await RatesService.shared.fetchAll(fiatCodes: codes)
            await MainActor.run {
                self.rates = snap
                self.isLoadingRates = false
            }
        } catch {
            let ns = error as NSError
            let message: String
            if let e = error as? RatesError {
                message = e.localizedDescription
            } else if ns.domain == NSURLErrorDomain {
                message = "Нет соединения с интернетом"
            } else {
                message = "Неизвестная ошибка"
            }
            await MainActor.run {
                self.ratesError = message
                self.isLoadingRates = false
            }
        }
    }
}

#Preview {
    BudgetView().environmentObject(AppState())
}
