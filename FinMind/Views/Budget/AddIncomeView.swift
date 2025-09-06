import SwiftUI

struct AddIncomeView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    /// Если передать запись — экран открывается в режиме редактирования
    var existing: Income? = nil

    @State private var title: String = ""
    @State private var amountInt: Int = 0
    @State private var currency: Currency = .rub
    @State private var isOneOff: Bool = false
    @State private var date: Date = Date()
    @State private var rec: Recurrence = .monthly

    var body: some View {
        Form {
            Section {
                TextField("Название", text: $title)

                // Сумма: целые числа, авто-группировка 1 000 000, удаление ведущего 0
                GroupedIntField(value: $amountInt, placeholder: "0")

                Picker("Валюта", selection: $currency) {
                    ForEach(Currency.supported, id: \.code) { c in
                        Text("\(c.code) \(c.symbol)").tag(c)
                    }
                }
            }

            Section("Тип") {
                Toggle("Разовый", isOn: $isOneOff)
                if isOneOff {
                    DatePicker("Дата", selection: $date, displayedComponents: .date)
                } else {
                    Picker("Периодичность", selection: $rec) {
                        ForEach(Recurrence.allCases, id: \.self) { r in
                            Text(r.localized).tag(r)
                        }
                    }
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(existing == nil ? "Новый доход" : "Редактировать доход")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Отмена") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(existing == nil ? "Сохранить" : "Обновить") { save() }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || amountInt <= 0)
            }
        }
        .onAppear { preload() }
    }

    private func preload() {
        guard let inc = existing else { return }
        title = inc.title
        amountInt = Int(inc.amount.rounded())
        currency = inc.currency
        switch inc.kind {
        case .recurring(let r):
            isOneOff = false
            rec = r
        case .oneOff(let d, _):
            isOneOff = true
            date = d
        }
    }

    private func save() {
        let kind: IncomeKind = isOneOff
            ? .oneOff(date: date, note: nil)
            : .recurring(rec)

        let model = Income(
            id: existing?.id ?? UUID(),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            amount: Double(amountInt),
            currency: currency,
            kind: kind
        )

        if existing == nil {
            appState.addIncome(model)
        } else {
            appState.updateIncome(model)
        }
        dismiss()
    }
}
