import SwiftUI

struct AddIncomeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var app: AppState
    
    @State private var name: String = ""
    @State private var amount: String = ""
    @State private var isRecurring: Bool = true
    @State private var periodicity: Periodicity = .monthly
    @State private var startDate: Date = Date()
    @State private var hasEndDate: Bool = false
    @State private var endDate: Date = Date()
    @State private var isPermanent: Bool = true
    
    @State private var oneOffDate: Date = Date()
    @State private var planned: Bool = false
    @State private var note: String = ""
    
    @State private var showError = false
    @State private var errorText = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Описание") {
                    TextField("Название", text: $name)
                    TextField("Сумма", text: $amount)
                        .keyboardType(.decimalPad)
                    Toggle("Постоянный доход", isOn: $isRecurring)
                }
                
                if isRecurring {
                    Section("Параметры постоянного дохода") {
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
                        Toggle("Пометить как постоянный", isOn: $isPermanent)
                    }
                } else {
                    Section("Разовый доход") {
                        DatePicker("Дата", selection: $oneOffDate, displayedComponents: .date)
                        Toggle("Плановый (в будущем)", isOn: $planned)
                    }
                }
                
                Section("Примечание") {
                    TextField("Опционально", text: $note)
                }
            }
            .navigationTitle("Новый доход")
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
            let inc = Income(name: name, amount: amt, kind: .recurring(periodicity: periodicity, start: startDate, end: end, isPermanent: isPermanent), note: note.isEmpty ? nil : note)
            app.addIncome(inc)
        } else {
            // if factual and in future -> block
            if !planned && oneOffDate > Date() {
                showError("Фактический разовый доход не может быть в будущем")
                return
            }
            let inc = Income(name: name, amount: amt, kind: .oneOff(date: oneOffDate, planned: planned), note: note.isEmpty ? nil : note)
            app.addIncome(inc)
        }
        
        dismiss()
    }
    
    private func showError(_ msg: String) {
        errorText = msg
        showError = true
    }
}

#Preview {
    AddIncomeView().environmentObject(AppState())
}
