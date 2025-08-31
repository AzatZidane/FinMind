import SwiftUI

struct AddGoalView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var targetAmount: String = ""
    @State private var deadline: Date = Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date()
    @State private var priority: Int = 2
    @State private var note: String = ""

    @State private var showError: Bool = false
    @State private var errorText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Цель")) {
                    TextField("Название", text: $name)
                    TextField("Сумма", text: $targetAmount)
                        .decimalKeyboardIfAvailable()
                    DatePicker("Дедлайн", selection: $deadline, displayedComponents: .date)
                    Stepper(value: $priority, in: 1...3) {
                        Text("Приоритет: \(priority)")
                    }
                }

                Section(header: Text("Примечание")) {
                    TextField("Опционально", text: $note)
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
            showValidation("Введите корректную сумму (> 0)")
            return
        }
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showValidation("Введите название")
            return
        }

        // если в модели Goal нет поля note — не передаём его
        let goal = Goal(
            name: name,
            targetAmount: amt,
            deadline: deadline,
            priority: priority
        )

        app.addGoal(goal)
        dismiss()
    }

    private func showValidation(_ msg: String) {
        errorText = msg
        showError = true
    }
}

#Preview {
    AddGoalView().environmentObject(AppState())
}
