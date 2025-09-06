import SwiftUI

struct AddGoalView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss

    /// Если передать запись — экран открывается в режиме редактирования
    var existing: Goal? = nil

    @State private var title: String = ""
    @State private var amountInt: Int = 0
    @State private var currency: Currency = .rub
    @State private var withDeadline: Bool = false
    @State private var deadline: Date = Date()

    var body: some View {
        Form {
            Section {
                TextField("Название", text: $title)
                GroupedIntField(value: $amountInt, placeholder: "0")

                Picker("Валюта", selection: $currency) {
                    ForEach(Currency.supported, id: \.code) { c in
                        Text("\(c.code) \(c.symbol)").tag(c)
                    }
                }
            }

            Section("Срок (опционально)") {
                Toggle("Указать срок", isOn: $withDeadline)
                if withDeadline {
                    DatePicker("Дедлайн", selection: $deadline, displayedComponents: .date)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(existing == nil ? "Новая цель" : "Редактировать цель")
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
        guard let g = existing else { return }
        title = g.title
        amountInt = Int(g.targetAmount.rounded())
        currency = g.currency
        if let d = g.deadline {
            withDeadline = true
            deadline = d
        } else {
            withDeadline = false
        }
    }

    private func save() {
        let model = Goal(
            id: existing?.id ?? UUID(),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            targetAmount: Double(amountInt),
            currency: currency,
            deadline: withDeadline ? deadline : nil
        )

        if existing == nil {
            app.addGoal(model)
        } else {
            app.updateGoal(model)
        }
        dismiss()
    }
}
