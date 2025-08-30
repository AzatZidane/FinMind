import SwiftUI

struct AddIncomeView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss

    // Основные поля
    @State private var name: String = ""
    @State private var amount: String = ""
    @State private var note: String = ""

    // Флаги
    @State private var isRecurring: Bool = false
    @State private var planned: Bool = false

    // Регулярный доход
    @State private var periodicity: Periodicity = Periodicity.allCases.first!
    @State private var startDate: Date = Date()
    @State private var hasEndDate: Bool = false
    @State private var endDate: Date = Date()
    @State private var isPermanent: Bool = false

    // Разовый доход
    @State private var oneOffDate: Date = Date()

    // Ошибки
    @State private var showError: Bool = false
    @State private var errorText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                // --- Секция 1: описание дохода
                Section {
                    TextField("Название", text: $name)
                        .textInputAutocapitalization(.words)
                    TextField("Сумма", text: $amount)
                    #if os(iOS)
                        .keyboardType(.decimalPad)
                    #endif
                    Toggle("Постоянный доход", isOn: $isRecurring)
                } header: {
                    Text("Описание")
                }

                // --- Секция 2: параметры (в зависимости от типа)
                if isRecurring {
                    Section {
                        Picker("Периодичность", selection: $periodicity) {
                            ForEach(Periodicity.allCases, id: \.self) { p in
                                Text(p.rawValue).tag(p as Periodicity)
                            }
                        }

                        DatePicker("Дата начала", selection: $startDate, displayedComponents: .date)

                        Toggle("Указать дату окончания", isOn: $hasEndDate)
                        if hasEndDate {
                            DatePicker("Дата окончания", selection: $endDate, displayedComponents: .date)
                        }

                        Toggle("Пометить как постоянный", isOn: $isPermanent)
                    } header: {
                        Text("Параметры постоянного дохода")
                    }
                } else {
                    Section {
                        DatePicker("Дата", selection: $oneOffDate, displayedComponents: .date)
                        Toggle("Плановый (в будущем)", isOn: $planned)
                    } header: {
                        Text("Разовый доход")
                    }
                }

                // --- Секция 3: примечание
                Section {
                    TextField("Примечание", text: $note)
                } header: {
                    Text("Дополнительно")
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

    // MARK: - Валидация и сохранение

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
            // Доп. валидация дат
            if hasEndDate && endDate < startDate {
                showValidation("Дата окончания не может быть раньше даты начала")
                return
            }

            let end: Date? = hasEndDate ? endDate : nil
            let inc = Income(
                name: name,
                amount: amt,
                kind: .recurring(
                    periodicity: periodicity,
                    start: startDate,
                    end: end,
                    isPermanent: isPermanent
                ),
                note: note.isEmpty ? nil : note
            )
            app.addIncome(inc)
        } else {
            if !planned && oneOffDate > Date() {
                showValidation("Фактический разовый доход не может быть в будущем")
                return
            }

            let inc = Income(
                name: name,
                amount: amt,
                kind: .oneOff(date: oneOffDate, planned: planned),
                note: note.isEmpty ? nil : note
            )
            app.addIncome(inc)
        }

        dismiss()
    }

    private func showValidation(_ msg: String) {
        errorText = msg
        showError = true
    }
}

#Preview {
    AddIncomeView()
        .environmentObject(AppState())
}
