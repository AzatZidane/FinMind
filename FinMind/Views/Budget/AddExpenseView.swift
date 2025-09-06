import SwiftUI

struct AddExpenseView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    var existing: Expense? = nil

    @State private var title: String = ""
    @State private var amountInt: Int = 0
    @State private var currency: Currency = .rub
    @State private var rec: Recurrence = .monthly
    @State private var isOneOff: Bool = false
    @State private var date: Date? = nil

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
                    DatePicker("Дата",
                               selection: Binding(get: { date ?? Date() },
                                                  set: { date = $0 }),
                               displayedComponents: .date)
                } else {
                    Picker("Периодичность", selection: $rec) {
                        ForEach(Recurrence.allCases) { Text($0.localized).tag($0) }
                    }
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(existing == nil ? "Новый расход" : "Редактировать расход")
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
        guard let e = existing else { return }
        title = e.title
        amountInt = Int(e.amount.rounded())
        currency = e.currency
        switch e.kind {
        case .recurring(let r): isOneOff = false; rec = r
        case .oneOff(let d, _): isOneOff = true; date = d
        }
    }

    private func save() {
        let kind: ExpenseKind = isOneOff ? .oneOff(date: date, note: nil) : .recurring(rec)
        let model = Expense(id: existing?.id ?? UUID(),
                            title: title.trimmingCharacters(in: .whitespaces),
                            amount: Double(amountInt),
                            currency: currency,
                            kind: kind)
        if existing == nil { appState.addExpense(model) } else { appState.updateExpense(model) }
        dismiss()
    }
}
