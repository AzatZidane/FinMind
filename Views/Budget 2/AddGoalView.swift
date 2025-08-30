import SwiftUI

struct AddGoalView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var app: AppState
    
    @State private var name: String = ""
    @State private var targetAmount: String = ""
    @State private var deadline: Date = Calendar.app.date(byAdding: .month, value: 6, to: Date()) ?? Date()
    @State private var priority: Int = 2
    
    @State private var showError = false
    @State private var errorText = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Цель") {
                    TextField("Название", text: $name)
                    TextField("Сумма", text: $targetAmount).keyboardType(.decimalPad)
                    DatePicker("Дедлайн", selection: $deadline, displayedComponents: .date)
                    Stepper(value: $priority, in: 1...3) {
                        Text("Приоритет: \(priority)")
                    }
                }
            }
            .navigationTitle("Новая цель")
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
        guard let amt = Double(targetAmount.replacingOccurrences(of: ",", with: ".")), amt > 0 else {
            showError("Введите корректную сумму (> 0)")
            return
        }
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            showError("Введите название")
            return
        }
        let g = Goal(name: name, targetAmount: amt, deadline: deadline, priority: priority)
        app.addGoal(g)
        dismiss()
    }
    
    private func showError(_ msg: String) {
        errorText = msg
        showError = true
    }
}

#Preview {
    AddGoalView().environmentObject(AppState())
}
