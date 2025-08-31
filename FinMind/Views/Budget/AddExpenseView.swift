import SwiftUI

struct AddExpenseView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var amount: String = ""
    @State private var category: ExpenseCategory = .other
    @State private var note: String = ""

    @State private var isRecurring: Bool = false
    @State private var planned: Bool = false

    @State private var periodicity: Periodicity = .monthly
    @State private var startDate: Date = Date()
    @State private var hasEndDate: Bool = false
    @State private var endDate: Date = Date()

    @State private var oneOffDate: Date = Date()

    @State private var showError: Bool = false
    @State private var errorText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Описание")) {
                    TextField("Название", text: $name)
                    TextField("Сумма", text: $amount)
                        .decimalKeyboardIfAvailable()
                    Picker("Категория", selection: $category) {
                        ForEach(ExpenseCategory.allCases, id: \.self) { c in
                            Text(c.rawValue).tag(c)
                        }
                    }
                }

                Section(header: Text("Тип")) {
                    Toggle("Повторяющийся расход", isOn: $isRecurring)
                }

                if isRecurring {
                    Section(header: Text("Параметры повтора")) {
                        Picker("Периодичность", selection: $periodicity) {
                            ForEach(Periodicity.allCases, id: \.self) { p in
                                Text(p.rawValue).tag(p)
                            }
                        }
                        DatePicker("Дата начала", selection: $startDate, displayedComponents: .date)
                        Toggle("Указать дату окончания", isOn: $hasEndDate)
                        if hasEndDate {
                            DatePicker("Дата окончания", selection: $endDate, displayedComponents: .date)
                        }
                    }
                } else {
                    Section(header: Text("Разовый расход")) {
                        DatePicker("Дата", selection: $oneOffDate, displayedComponents: .date)
                        Toggle("Запланированный", isOn: $planned)
                    }
                }

                Section(header: Text("Примечание")) {
                    TextField("Опционально", text: $note)
                }
            }
            .navigationTitle("Новый расход")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }
                }
            }
            .alert("Ошибка", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorText)
            }
        }
    }

    private func save() {
        guard let amt = Double(amount.replacingOccurrences(of: ",", with: ".")), amt > 0 else {
            showValidation("Введите корректную сумму (> 0)")
            return
        }
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showValidation("Введите название")
            return
        }

        if isRecurring {
            let end: Date? = hasEndDate ? endDate : nil
            let exp = Expense(
                name: name,
                amount: amt,
                category: category,
                kind: .recurring(periodicity: periodicity, start: startDate, end: end),
                note: note.isEmpty ? nil : note
            )
            app.addExpense(exp)
        } else {
            if !planned && oneOffDate > Date() {
                showValidation("Фактический разовый расход не может быть в будущем")
                return
            }
            let exp = Expense(
                name: name,
                amount: amt,
                category: category,
                kind: .oneOff(date: oneOffDate, planned: planned),
                note: note.isEmpty ? nil : note
            )
            app.addExpense(exp)
        }

        dismiss()
    }

    private func showValidation(_ msg: String) {
        errorText = msg
        showError = true
    }
}

#Preview {
    AddExpenseView().environmentObject(AppState())
}
