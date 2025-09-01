import SwiftUI



struct AdvisorView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        NavigationStack {
            List {
                Section("Чат с GPT") {
                    NavigationLink("Открыть чат") {
                        AdvisorChatView().environmentObject(app)
                    }
                }

                // остальные секции: 50/30/20, Подушка, Долги...
                plan503020Section
                cushionSection
                debtsAdviceSection
            }
            .navigationTitle(UIStrings.tab3)
        }
    }

    // остальной код (plan503020Section, cushionSection, debtsAdviceSection) оставь как есть
}



struct AdvisorView: View {
    @EnvironmentObject var app: AppState

    // Ввод для калькуляторов
    @State private var monthlyIncomeText: String = ""   // ежемесячный доход (для 50/30/20)
    @State private var monthlySpendText: String  = ""   // ежемесячные расходы (для подушки)
    @State private var cushionMonths: Int = 6           // месяцев подушки

    var body: some View {
        NavigationStack {
            List {
                // ← ВХОД В ЧАТ GPT
                Section("Чат с GPT") {
                    NavigationLink("Начать чат с ИИ помощником") { AdvisorChatView() }
                }

                plan503020Section
                cushionSection
                debtsAdviceSection
            }
            .navigationTitle(UIStrings.tab3) // "Советник"
        }
    }
}

// MARK: - 50/30/20

private extension AdvisorView {
    var plan503020Section: some View {
        Section("План 50/30/20") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Разделите чистый ежемесячный доход на 50% обязательные, 30% желательные, 20% накопления.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                HStack {
                    TextField("Ежемесячный доход", text: $monthlyIncomeText)
                        .textFieldStyle(.roundedBorder)
                        .decimalKeyboardIfAvailable()
                    if let inc = parseMoney(monthlyIncomeText) {
                        Text(inc.asMoney)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                if let inc = parseMoney(monthlyIncomeText), inc > 0 {
                    let needs  = inc * 0.50
                    let wants  = inc * 0.30
                    let saving = inc * 0.20
                    LabeledContent("Обязательные") { Text(needs.asMoney) }
                    LabeledContent("Желательные") { Text(wants.asMoney) }
                    LabeledContent("Накопления")  { Text(saving.asMoney) }
                } else {
                    Text("Введите сумму дохода, чтобы увидеть расчёт.").foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Финансовая подушка

private extension AdvisorView {
    var cushionSection: some View {
        Section("Финансовая подушка") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Цель — покрыть расходы на N месяцев без дохода.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                HStack {
                    TextField("Ежемесячные расходы", text: $monthlySpendText)
                        .textFieldStyle(.roundedBorder)
                        .decimalKeyboardIfAvailable()
                    if let s = parseMoney(monthlySpendText) {
                        Text(s.asMoney).font(.caption).foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 12) {
                    Text("Месяцев: \(cushionMonths)")
                    Slider(value: Binding(
                        get: { Double(cushionMonths) },
                        set: { cushionMonths = Int($0) }
                    ), in: 1...24, step: 1)
                }

                if let spend = parseMoney(monthlySpendText), spend > 0 {
                    let goal = spend * Double(cushionMonths)
                    LabeledContent("Цель подушки") { Text(goal.asMoney) }
                } else {
                    Text("Введите ежемесячные расходы, чтобы увидеть цель.").foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Приоритет погашения долгов

private extension AdvisorView {
    var debtsAdviceSection: some View {
        Section("Приоритет погашения долгов") {
            if debtInfos.isEmpty {
                Text("Долгов пока нет. Добавьте их на вкладке «Долги».")
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Две стратегии:").font(.footnote).foregroundStyle(.secondary)
                    Text("• Аваланш — сначала самый высокий APR (минимальная переплата).")
                        .font(.footnote).foregroundStyle(.secondary)
                    Text("• Сноуболл — сначала самая маленькая сумма (быстрые победы).")
                        .font(.footnote).foregroundStyle(.secondary)
                }

                if !avalancheOrder.isEmpty {
                    Text("Аваланш (по APR):").font(.subheadline).padding(.top, 4)
                    ForEach(Array(avalancheOrder.enumerated()), id: \.offset) { idx, d in
                        HStack {
                            Text("\(idx + 1). \(d.name)")
                            Spacer()
                            if let apr = d.apr {
                                Text(String(format: "%.2f%%", apr)).foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if !snowballOrder.isEmpty {
                    Text("Сноуболл (по сумме):").font(.subheadline).padding(.top, 4)
                    ForEach(Array(snowballOrder.enumerated()), id: \.offset) { idx, d in
                        HStack {
                            Text("\(idx + 1). \(d.name)")
                            Spacer()
                            Text(d.baseAmount.asMoney).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    struct DebtInfo {
        let name: String
        let baseAmount: Double
        let apr: Double?
    }

    var debtInfos: [DebtInfo] {
        app.debts.map { d in
            switch d.input {
            case .monthlyPayment(let amount, _):
                return DebtInfo(name: d.name, baseAmount: amount, apr: nil)
            case .loan(let principal, let apr, _, _, _):
                return DebtInfo(name: d.name, baseAmount: principal, apr: apr)
            }
        }
    }

    var avalancheOrder: [DebtInfo] {
        debtInfos.sorted { a, b in
            switch (a.apr, b.apr) {
            case let (la?, lb?):
                if la == lb { return a.baseAmount > b.baseAmount }
                return la > lb
            case (_?, nil): return true
            case (nil, _?): return false
            default:        return a.baseAmount > b.baseAmount
            }
        }
    }

    var snowballOrder: [DebtInfo] {
        debtInfos.sorted { $0.baseAmount < $1.baseAmount }
    }
}

// MARK: - Вспомогательное

private extension AdvisorView {
    func parseMoney(_ s: String) -> Double? {
        let normalized = s.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }
}

#Preview {
    AdvisorView().environmentObject(AppState())
}
