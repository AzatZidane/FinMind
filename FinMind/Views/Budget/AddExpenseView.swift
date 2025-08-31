import SwiftUI

struct AddExpenseView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss

    // Основные поля
    @State private var name: String = ""
    @State private var amount: String = ""
    @State private var category: ExpenseCategory = .other
    @State private var note: String = ""

    // Флаги
    @State private var isRecurring: Bool = false
    @State private var planned: Bool = false

    // Регулярный расход
    @State private var periodicity: Periodicity = .monthly
    @State private var startDate: Date = Date()
    @State private var hasEndDate: Bool = false
    @State private var endDate: Date = Date()

    // Разовый расход
    @State private var oneOffDate: Date = Date()

    // Ошибки
    @State private var showError: Bool = false
    @State private var errorText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                // --- Секция 1: описание
                Section(header: Text("Описание")) {
                    TextField("Название", text: $name)
                        .capWordsIfAvailable()            // iOS: автокапитализация слов
                    TextField("Сумма", text: $amount)
                        .decimalKeyboardIfAvailable()     // iOS: цифровая клавиатура
                    Picker("Категория", selection: $category) {
                        ForEach(ExpenseCategory.allCases, id: \.self) { c in
                            Text(c.rawValue).tag(c)
                        }
                    }
                }

                // --- Секция 2: тип расхода
                Section(header: Text("Тип")) {
                    Toggle("Повторяющийся расход", isOn: $isRecurring)
                }

                // --- Секция 3: параметры в зависимости от типа
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

                // --- Секция 4: примечание
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

    // MARK: - Сохранение

    private func save() {
        // Валидация суммы
        guard let amt = Double(amount.replacingOccurrences(of: ",", with: ".")), amt > 0 else {
            showValidation("Введите корректную сумму (> 0)")
            return
        }
        // Валидация названия
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showValidation("Введите название")
            return
        }

        if isRecurring {
            if hasEndDate && endDate < startDate {
                showValidation("Дата окончания не может быть раньше даты начала")
                return
            }
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

// MARK: - Платформенно‑безопасные модификаторы (для iOS ок, на macOS — игнорируются)
private 

    @ViewBuilder
    func decimalKeyboardIfAvailable() -> some View {
        #if canImport(UIKit)
        self.keyboardType(.decimalPad)
        #else
        self
        #endif
    }
}

#Preview {
    AddExpenseView()
        .environmentObject(AppState())
}
