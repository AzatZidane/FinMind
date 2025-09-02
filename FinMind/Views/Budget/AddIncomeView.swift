import SwiftUI

struct AddIncomeView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var title: String = ""
    @State private var amount: Decimal? = nil
    @State private var currency: Currency = .rub
    @State private var isOneOff: Bool = false
    @State private var date: Date = Date()
    @State private var rec: Recurrence = .monthly

    var body: some View {
        NavigationStack {
            Form {
                Section {
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
                Section("Тип") {
                    Toggle("Разовый", isOn: $isOneOff)
                    if isOneOff {
                        DatePicker("Дата", selection: $date, displayedComponents: .date)
                    } else {
                        Picker("Периодичность", selection: $rec) {
                            ForEach(Recurrence.allCases) { Text($0.localized).tag($0) }
                        }
                    }
                }
            }
            .navigationTitle("Новый доход")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        let amt = NSDecimalNumber(decimal: amount ?? 0).doubleValue
                        let kind: IncomeKind = isOneOff ? .oneOff(date: date, note: nil) : .recurring(rec)
                        let item = Income(title: title, amount: amt, currency: currency, kind: kind)
                        appState.addIncome(item); dismiss()
                    }.disabled(title.isEmpty || (amount ?? 0) == 0)
                }
            }
        }
    }
}

private extension Recurrence {
    var localized: String {
        switch self {
        case .daily: "Ежедневно"; case .weekly: "Еженедельно"; case .monthly: "Ежемесячно"
        case .quarterly: "Ежеквартально"; case .yearly: "Ежегодно"
        }
    }
}
