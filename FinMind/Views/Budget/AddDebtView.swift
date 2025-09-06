import SwiftUI

struct AddDebtView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var app: AppState

    var existing: Debt? = nil

    @State private var title: String = ""
    @State private var monthlyInt: Int = 0
    @State private var currency: Currency = .rub

    var body: some View {
        Form {
            Section("Ежемесячный платёж") {
                TextField("Название", text: $title)
                GroupedIntField(value: $monthlyInt, placeholder: "0")
                Picker("Валюта", selection: $currency) {
                    ForEach(Currency.supported) { c in
                        Text("\(c.code) \(c.symbol)").tag(c)
                    }
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(existing == nil ? "Новый долг" : "Редактировать долг")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button(existing == nil ? "Сохранить" : "Обновить") { save() }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || monthlyInt <= 0)
            }
        }
        .onAppear { preload() }
    }

    private func preload() {
        guard let d = existing else { return }
        title = d.title
        monthlyInt = Int(d.obligatoryMonthlyPayment.rounded())
        currency = d.currency
    }

    private func save() {
        let model = Debt(id: existing?.id ?? UUID(),
                         title: title.trimmingCharacters(in: .whitespaces),
                         obligatoryMonthlyPayment: Double(monthlyInt),
                         currency: currency)
        if existing == nil { app.addDebt(model) } else { app.updateDebt(model) }
        dismiss()
    }
}

#Preview {
    AddDebtView().environmentObject(AppState())
}
