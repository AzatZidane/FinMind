import SwiftUI

struct EditIncomeView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    let income: Income

    @State private var title: String
    @State private var amount: Decimal?
    @State private var currency: Currency
    @State private var isOneOff: Bool
    @State private var date: Date
    @State private var note: String = ""
    @State private var rec: Recurrence

    init(income: Income) {
        self.income = income
        _title = State(initialValue: income.title)
        _amount = State(initialValue: Decimal(income.amount))
        _currency = State(initialValue: income.currency)
        switch income.kind {
        case .oneOff(let d, let n):
            _isOneOff = State(initialValue: true)
            _date = State(initialValue: d)
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
            .navigationTitle("Ред. доход")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        var edited = income
                        edited.title = title
                        edited.amount = NSDecimalNumber(decimal: amount ?? 0).doubleValue
                        edited.currency = currency
                        edited.kind = isOneOff
                            ? .oneOff(date: date, note: note.isEmpty ? nil : note)
                            : .recurring(rec)
                        if let idx = appState.incomes.firstIndex(where: { $0.id == income.id }) {
                            appState.incomes[idx] = edited
                        }
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (amount ?? 0) == 0)
                }
            }
        }
    }
}
