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
                Section {
                    Picker("Режим", selection: $mode) {
                        ForEach(Mode.allCases) { m in
                            Text(m.rawValue).tag(m as Mode)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Тип долга")
                }

                if mode == .monthly {
                    Section {
                        TextField("Название", text: $monthlyName)
                            .capWordsIfAvailable()
                        TextField("Сумма", text: $monthlyAmount)
                            .decimalKeyboardIfAvailable()
                        Toggle("Минимальный платёж", isOn: $isMinimum)
                    } header: {
                        Text("Ежемесячный платёж")
                    }
                } else {
                    Section {
                        TextField("Название", text: $loanName)
                            .capWordsIfAvailable()
                        TextField("Сумма кредита", text: $principal)
                            .decimalKeyboardIfAvailable()
                        TextField("Ставка APR, %", text: $apr)
                            .decimalKeyboardIfAvailable()
                        TextField("Срок, месяцев", text: $termMonths)
                            .numberKeyboardIfAvailable()
                        TextField("Грейс-период, мес (опц.)", text: $graceMonths)
                            .numberKeyboardIfAvailable()
                        TextField("Мин. платёж (опц.)", text: $minPayment)
                            .decimalKeyboardIfAvailable()
                    } header: {
                        Text("Параметры кредита")
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
            let grace = Int(graceMonths) // опционально
            let min = Double(minPayment.replacingOccurrences(of: ",", with: ".")) // опционально

            guard !loanName.trimmingCharacters(in: .whitespaces).isEmpty else {
                showError("Введите название")
                return
            }
            let d = Debt(
                name: loanName,
                input: .loan(
                    principal: p,
                    apr: a,
                    termMonths: t,
                    graceMonths: grace,
                    minPayment: min
                )
            )
            app.addDebt(d)
        }

        dismiss()
    }

    private func showError(_ msg: String) {
        errorText = msg
        showError = true
    }
}

// Платформенно‑безопасные модификаторы (на iOS работают, на macOS/старых SDK — игнорируются)
private extension View {
    @ViewBuilder
    func capWordsIfAvailable() -> some View {
        #if canImport(UIKit)
        if #available(iOS 15.0, *) {
            self.textInputAutocapitalization(.words)
        } else {
            self.autocapitalization(.words)
        }
        #else
        self
        #endif
    }

    @ViewBuilder
    func decimalKeyboardIfAvailable() -> some View {
        #if canImport(UIKit)
        self.keyboardType(.decimalPad)
        #else
        self
        #endif
    }

    @ViewBuilder
    func numberKeyboardIfAvailable() -> some View {
        #if canImport(UIKit)
        self.keyboardType(.numberPad)
        #else
        self
        #endif
    }
}

#Preview {
    AddDebtView().environmentObject(AppState())
}
