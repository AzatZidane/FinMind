import SwiftUI

struct EditExpenseView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    let expense: Expense

    @State private var title: String
    @State private var amount: Decimal?
    @State private var currency: Currency
    @State private var isOneOff: Bool
    @State private var date: Date
    @State private var note: String = ""
    @State private var rec: Recurrence

    init(expense: Expense) {
        self.expense = expense
        _title = State(initialValue: expense.title)
        _amount = State(initialValue: Decimal(expense.amount))
        _currency = State(initialValue: expense.currency)
        switch expense.kind {
        case .oneOff(let d, let n):
            _isOneOff = State(initialValue: true)
            _date = State(initialValue: d ?? Date())
            _note = State(initialValue: n ?? "")
            _rec = State(initialValue: .monthly)
        case .recurring(let r):
            _isOneOff = State(initialValue: false)
            _date = State(initialValue: Date())
            _rec = State(initialValue: r)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
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
            .navigationTitle("Ред. расход")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        var edited = expense
                        edited.title = title
                        edited.amount = NSDecimalNumber(decimal: amount ?? 0).doubleValue
                        edited.currency = currency
                        edited.kind = isOneOff
                            ? .oneOff(date: date, note: note.isEmpty ? nil : note)
                            : .recurring(rec)
                        if let idx = appState.expenses.firstIndex(where: { $0.id == expense.id }) {
                            appState.expenses[idx] = edited
                        }
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (amount ?? 0) == 0)
                }
            }
        }
    }
}
