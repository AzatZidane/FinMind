import SwiftUI

struct AddExpenseView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var title: String = ""
    @State private var amount: Decimal? = nil
    @State private var currency: Currency = .rub
    @State private var rec: Recurrence = .monthly

    var body: some View {
        NavigationStack {
            Form {
                TextField("Название", text: $title)

                MoneyTextField(value: $amount,
                               fractionDigits: appState.fractionDigits(for: currency),
                               groupingSeparator: ".",
                               decimalSeparator: ",",
                               placeholder: "0")

                Picker("Валюта", selection: $currency) {
                    ForEach(Currency.supported, id: \.code) { c in
                        Text("\(c.code) \n\(c.symbol)").tag(c as Currency)
                    }
                }

                Picker("Периодичность", selection: $rec) {
                    ForEach(Recurrence.allCases) { Text($0.localized).tag($0) }
                }
            }
            .navigationTitle("Новый расход")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        let amt = NSDecimalNumber(decimal: amount ?? 0).doubleValue
                        let item = Expense(title: title, amount: amt, currency: currency, kind: .recurring(rec))
                        appState.addExpense(item)
                        dismiss()
                    }
                    .disabled(title.isEmpty || (amount ?? 0) == 0)
                }
            }
        }
    }
}
