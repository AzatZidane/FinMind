import SwiftUI

struct AddDebtView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var app: AppState
    
    enum Mode: String, CaseIterable, Identifiable {
        case monthly = "Ежемесячный платёж"
        case loan = "Параметры кредита"
        var id: String { rawValue }
    }
    
    @State private var mode: Mode = .monthly
    
    // Monthly payment mode
    @State private var monthlyName: String = ""
    @State private var monthlyAmount: String = ""
    @State private var isMinimum: Bool = true
    
    // Loan mode
    @State private var loanName: String = ""
    @State private var principal: String = ""
    @State private var apr: String = "" // %
    @State private var termMonths: String = ""
    @State private var graceMonths: String = ""
    @State private var minPayment: String = ""
    
    @State private var showError = false
    @State private var errorText = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Picker("Режим", selection: $mode) {
                    ForEach(Mode.allCases) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                
                if mode == .monthly {
                    Section("Ежемесячный платёж") {
                        TextField("Название", text: $monthlyName)
                        TextField("Сумма", text: $monthlyAmount).keyboardType(.decimalPad)
                        Toggle("Минимальный платёж", isOn: $isMinimum)
                    }
                } else {
                    Section("Параметры кредита") {
                        TextField("Название", text: $loanName)
                        TextField("Сумма кредита", text: $principal).keyboardType(.decimalPad)
                        TextField("Ставка APR, %", text: $apr).keyboardType(.decimalPad)
                        TextField("Срок, месяцев", text: $termMonths).keyboardType(.numberPad)
                        TextField("Грейс-период, мес (опц.)", text: $graceMonths).keyboardType(.numberPad)
                        TextField("Мин. платёж (опц.)", text: $minPayment).keyboardType(.decimalPad)
                    }
                }
            }
            .navigationTitle("Новый долг")
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
        switch mode {
        case .monthly:
            guard let amt = Double(monthlyAmount.replacingOccurrences(of: ",", with: ".")), amt > 0 else {
                showError("Введите сумму (> 0)")
                return
            }
            guard !monthlyName.trimmingCharacters(in: .whitespaces).isEmpty else {
                showError("Введите название")
                return
            }
            let d = Debt(name: monthlyName, input: .monthlyPayment(amount: amt, isMinimum: isMinimum))
            app.addDebt(d)
        case .loan:
            guard let p = Double(principal.replacingOccurrences(of: ",", with: ".")), p > 0 else {
                showError("Введите корректную сумму кредита")
                return
            }
            guard let a = Double(apr.replacingOccurrences(of: ",", with: ".")), a >= 0 else {
                showError("Введите ставку APR (%)")
                return
            }
            guard let t = Int(termMonths), t > 0 else {
                showError("Введите срок в месяцах (> 0)")
                return
            }
            let grace = Int(graceMonths)
            let min = Double(minPayment.replacingOccurrences(of: ",", with: "."))
            guard !loanName.trimmingCharacters(in: .whitespaces).isEmpty else {
                showError("Введите название")
                return
            }
            let d = Debt(name: loanName, input: .loan(principal: p, apr: a, termMonths: t, graceMonths: grace, minPayment: min))
            app.addDebt(d)
        }
        
        dismiss()
    }
    
    private func showError(_ msg: String) {
        errorText = msg
        showError = true
    }
}

#Preview {
    AddDebtView().environmentObject(AppState())
}
