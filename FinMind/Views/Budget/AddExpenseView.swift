import SwiftUI

struct AddExpenseView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var title: String = ""
    @State private var amount: Decimal? = nil
    @State private var currency: Currency = .rub

    // Новое: разовый / периодический
    @State private var isOneOff: Bool = false
    @State private var date: Date = Date()
    @State private var note: String = ""
    @State private var rec: Recurrence = .monthly

    var body: some View {
        NavigationStack {
            Form {
                // Основные поля
                Section {
                    TextField("Название", text: $title)

                    MoneyTextField(
                        value: $amount,
                        fractionDigits: appState.fractionDigits(for: currency),
                        groupingSeparator: ".",
                        decimalSeparator: ",",
                        placeholder: "0"
                    )

                    Picker("Валюта", selection: $currency) {
                        ForEach(Currency.supported, id: \.code) { c in
                            Text("\(c.code) \(c.symbol)").tag(c as Currency)
                        }
                    }
                }

                // Тип расхода
                Section("Тип") {
                    Toggle("Разовый", isOn: $isOneOff)

                    if isOneOff {
                        DatePicker("Дата", selection: $date, displayedComponents: .date)
                        TextField("Заметка (необязательно)", text: $note)
                    } else {
                        Picker("Периодичность", selection: $rec) {
                            ForEach(Recurrence.allCases) { r in
                                Text(r.localized).tag(r)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Новый расход")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        let amt = NSDecimalNumber(decimal: amount ?? 0).doubleValue
                        let kind: ExpenseKind = isOneOff
                            ? .oneOff(date: date, note: note.isEmpty ? nil : note)
                            : .recurring(rec)

                        let item = Expense(
                            id: UUID(),
                            title: title,
                            amount: amt,
                            currency: currency,
                            kind: kind
                        )
                        appState.addExpense(item)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (amount ?? 0) == 0)
                }
            }
        }
    }
}
