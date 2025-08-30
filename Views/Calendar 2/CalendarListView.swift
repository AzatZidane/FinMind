import SwiftUI

struct CalendarListView: View {
    @EnvironmentObject var app: AppState
    @State private var presentAdd = false
    
    var grouped: [(Date, [DailyEntry])] {
        let grouped = Dictionary(grouping: app.dailyEntries) { $0.date.startOfMonth() }
        let sorted = grouped.sorted { $0.key < $1.key }
        return sorted
    }
    
    var body: some View {
        List {
            ForEach(grouped, id: \.0) { (month, items) in
                Section(month.formatted(Date.FormatStyle().month(.wide).year())) {
                    ForEach(items.sorted(by: { $0.date < $1.date })) { e in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(e.type.rawValue): \(e.name)")
                                    .font(.headline)
                                Text("\(e.planned ? "План" : "Факт") • \(e.date.formatted(date: .abbreviated, time: .omitted))\(e.category != nil ? " • \(e.category!.rawValue)" : "")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(e.amount.moneyString).font(.body.monospacedDigit())
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                app.removeDailyEntry(e)
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Календарь")
        .toolbar {
            Button {
                presentAdd = true
            } label: {
                Image(systemName: "plus")
            }
        }
        .sheet(isPresented: $presentAdd) {
            AddDailyEntryView().environmentObject(app)
        }
    }
}

struct AddDailyEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var app: AppState
    
    @State private var date: Date = Date()
    @State private var type: EntryType = .expense
    @State private var name: String = ""
    @State private var amount: String = ""
    @State private var planned: Bool = true
    @State private var category: ExpenseCategory = .other
    
    @State private var showError = false
    @State private var errorText = ""
    
    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Дата", selection: $date, displayedComponents: .date)
                Picker("Тип", selection: $type) {
                    ForEach(EntryType.allCases) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
                TextField("Название", text: $name)
                TextField("Сумма", text: $amount).keyboardType(.decimalPad)
                
                if type == .expense {
                    Picker("Категория", selection: $category) {
                        ForEach(ExpenseCategory.allCases) { c in
                            Text(c.rawValue).tag(c)
                        }
                    }
                }
                
                Toggle("Плановый", isOn: $planned)
            }
            .navigationTitle("Новая запись")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }
                }
            }
            .alert("Ошибка", isPresented: $showError) {
                Button("OK", role: .cancel) {}
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
        if !planned && date > Date() {
            showError("Фактическая запись не может быть в будущем")
            return
        }
        
        if type == .expense {
            let entry = DailyEntry(date: date, type: .expense, name: name, amount: amt, category: category, planned: planned)
            app.addDailyEntry(entry)
        } else {
            let entry = DailyEntry(date: date, type: .income, name: name, amount: amt, category: nil, planned: planned)
            app.addDailyEntry(entry)
        }
        dismiss()
    }
    
    private func showError(_ msg: String) {
        errorText = msg
        showError = true
    }
}

#Preview {
    NavigationStack {
        CalendarListView().environmentObject(AppState())
    }
}
