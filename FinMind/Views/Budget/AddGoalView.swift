import SwiftUI

struct AddGoalView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var title: String = ""
    @State private var amount: Decimal? = nil
    @State private var currency: Currency = .rub

    var body: some View {
        NavigationStack {
            Form {
                TextField("Название", text: $title)
                MoneyTextField(value: $amount,
                               fractionDigits: currency.fractionDigits,
                               groupingSeparator: ".",
                               decimalSeparator: ",",
                               placeholder: "0,00")
                Picker("Валюта", selection: $currency) {
                    ForEach(Currency.supported) { Text("\($0.code) \($0.symbol)").tag($0) }
                }
            }
            .navigationTitle("Новая цель")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        let amt = NSDecimalNumber(decimal: amount ?? 0).doubleValue
                        let item = Goal(title: title, targetAmount: amt, currency: currency)
                        appState.addGoal(item); dismiss()
                    }.disabled(title.isEmpty || (amount ?? 0) == 0)
                }
            }
        }
    }
}
