import SwiftUI

struct CalendarListView: View {
    @EnvironmentObject var app: AppState

    // Поиск + фильтр по сумме
    @State private var query: String = ""
    @State private var minAmountText: String = ""

    // MARK: - Парсинг минимальной суммы
    private var minAmount: Double? {
        let normalized = minAmountText.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }

    // MARK: - Отфильтрованные данные (разбиваем логику на простые шаги)
    private var filteredIncomes: [Income] {
        var items = app.incomes

        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            items = items.filter { $0.name.lowercased().contains(q) }
        }
        if let min = minAmount {
            items = items.filter { $0.amount >= min }
        }
        // при желании можно отсортировать, например по имени:
        // items.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return items
    }

    private var filteredExpenses: [Expense] {
        var items = app.expenses

        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            items = items.filter { $0.name.lowercased().contains(q) }
        }
        if let min = minAmount {
            items = items.filter { $0.amount >= min }
        }
        return items
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                // Панель фильтров
                filterBar

                // Список
                List {
                    if !filteredIncomes.isEmpty {
                        Section("Доходы") {
                            ForEach(Array(filteredIncomes.enumerated()), id: \.offset) { _, income in
                                incomeRow(income)
                            }
                        }
                    }

                    if !filteredExpenses.isEmpty {
                        Section("Расходы") {
                            ForEach(Array(filteredExpenses.enumerated()), id: \.offset) { _, expense in
                                expenseRow(expense)
                            }
                        }
                    }

                    if filteredIncomes.isEmpty && filteredExpenses.isEmpty {
                        Section {
                            Text("Ничего не найдено")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                #if os(iOS)
                    .listStyle(.insetGrouped)
                #else
                    .listStyle(.inset)       // или просто убери стиль на macOS
                #endif

            }
            .padding(.top, 8)
            .navigationTitle("Календарь")
        }
    }

    // MARK: - Вью: Панель фильтров
    private var filterBar: some View {
        VStack(spacing: 8) {
            // Поиск по названию
            TextField("Поиск по названию…", text: $query)
                .textFieldStyle(.roundedBorder)

            // Фильтр по минимальной сумме
            HStack {
                TextField("Мин. сумма", text: $minAmountText)
                    .textFieldStyle(.roundedBorder)
                #if canImport(UIKit)
                    .keyboardType(.decimalPad)   // на iOS появится цифровая клавиатура
                #endif

                if let min = minAmount {
                    Text("≥ \(min, specifier: "%.2f")")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Вью: строки списка
    @ViewBuilder
    private func incomeRow(_ inc: Income) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(inc.name)
                    .font(.body)
                Text("Доход")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(inc.amount, specifier: "%.2f")")
                .font(.headline.monospacedDigit())
        }
    }

    @ViewBuilder
    private func expenseRow(_ exp: Expense) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(exp.name)
                    .font(.body)
                Text("Расход")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(exp.amount, specifier: "%.2f")")
                .font(.headline.monospacedDigit())
        }
    }
}

#Preview {
    CalendarListView()
        .environmentObject(AppState())
}
