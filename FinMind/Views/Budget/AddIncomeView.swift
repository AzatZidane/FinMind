import SwiftUI

struct AddIncomeView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    // Если передать запись — откроется режим редактирования
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
                GroupedIntField(value: $amountInt, placeholder: "0")
                Picker("Валюта", selection: $currency) {
                    ForEach(Currency.supported) { c in
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
                        ForEach(Recurrence.allCases) { Text($0.localized).tag($0) }
                    }
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(existing == nil ? "Новый доход" : "Редактировать доход")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button(existing == nil ? "Сохранить" : "Обновить") { save() }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || amountInt <= 0)
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
        case .recurring(let r): isOneOff = false; rec = r
        case .oneOff(let d, _): isOneOff = true; date = d
        }
    }

    private func save() {
        let kind: IncomeKind = isOneOff ? .oneOff(date: date, note: nil) : .recurring(rec)
        let model = Income(id: existing?.id ?? UUID(),
                           title: title.trimmingCharacters(in: .whitespaces),
                           amount: Double(amountInt),
                           currency: currency,
                           kind: kind)
        if existing == nil { appState.addIncome(model) } else { appState.updateIncome(model) }
        dismiss()
    }
}

private extension Recurrence {
    var localized: String {
        switch self {
        case .daily: "Ежедневно"
        case .weekly: "Еженедельно"
        case .monthly: "Ежемесячно"
        case .quarterly: "Ежеквартально"
        case .yearly: "Ежегодно"
        }
    }
}
