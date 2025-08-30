import SwiftUI

struct AddExpenseView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var app: AppState
    
    @State private var name: String = ""
    @State private var amount: String = ""
    @State private var category: ExpenseCategory = .other
    @State private var isRecurring: Bool = true
    @State private var periodicity: Periodicity = .monthly
    @State private var startDate: Date = Date()
    @State private var hasEndDate: Bool = false
    @State private var endDate: Date = Date()
    
    // One-off to calendar (planned/fact)
    @State private var asOneOffDailyEntry: Bool = false
    @State private var oneOffDate: Date = Date()
    @State private var planned: Bool = true
    
    @State private var note: String = ""
    @State private var showError = false
    @State private var errorText = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Описание") {
                    TextField("Название", text: $name)
                    TextField("Сумма", text: $amount).keyboardType(.decimalPad)
                    Picker("Категория", selection: $category) {
                        ForEach(ExpenseCategory.allCases) { c in
                            Text(c.rawValue).tag(c)
                        }
                    }
                }
                
                Section {
                    Toggle("Повторяющийся расход", isOn: $isRecurring)
                }
                
                if isRecurring {
                    Section("Параметры повторения") {
                        Picker("Периодичность", selection: $periodicity) {
                            ForEach(Periodicity.allCases) { p in
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
                    Section("Разовый расход (событие)") {
                        Toggle("Добавить в календарь", isOn: $asOneOffDailyEntry)
                        DatePicker("Дата", selection: $oneOffDate, displayedComponents: .date)
                        Toggle("Плановый", isOn: $planned)
                    }
                }
                
                Section("Примечание") {
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
            showError("Введите корректную сумму (> 0)")
            return
        }
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            showError("Введите название")
            return
        }
        
        if isRecurring {
            let end: Date? = hasEndDate ? endDate : nil
            let exp = Expense(name: name, amount: amt, category: category, kind: .recurring(periodicity: periodicity, start: startDate, end: end), note: note.isEmpty ? nil : note)
            app.addExpense(exp)
        } else if asOneOffDailyEntry {
            if !planned && oneOffDate > Date() {
                showError("Фактический расход не может быть в будущем")
                return
            }
            let entry = DailyEntry(date: oneOffDate, type: .expense, name: name, amount: amt, category: category, planned: planned)
            app.addDailyEntry(entry)
        } else {
            // store as one-off expense in catalog
            let exp = Expense(name: name, amount: amt, category: category, kind: .oneOff(date: oneOffDate, planned: planned), note: note.isEmpty ? nil : note)
            app.addExpense(exp)
        }
        
        dismiss()
    }
    
    private func showError(_ msg: String) {
        errorText = msg
        showError = true
    }
}

#Preview {
    AddExpenseView().environmentObject(AppState())
}
