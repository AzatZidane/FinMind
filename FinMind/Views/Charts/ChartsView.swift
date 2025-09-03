import SwiftUI
import Charts

@available(iOS 16.0, *)
private enum ChartKind: String, CaseIterable, Identifiable {
    case bars = "Столбики"
    case lines = "Линия"
    var id: String { rawValue }
}

@available(iOS 16.0, *)
private enum Bucket: String, CaseIterable, Identifiable {
    case month = "Месяцы"
    case quarter = "Кварталы"
    var id: String { rawValue }
}

@available(iOS 16.0, *)
private enum RangeMonths: Int, CaseIterable, Identifiable {
    case m6 = 6, m12 = 12, m24 = 24
    var title: String {
        switch self {
        case .m6:  return "6м"
        case .m12: return "12м"
        case .m24: return "24м"
        }
    }
    var id: Int { rawValue }
}

@available(iOS 16.0, *)
private enum Series: String, CaseIterable, Identifiable {
    case income = "Доходы"
    case expense = "Расходы"
    case net = "Итог"
    var id: String { rawValue }
}

@available(iOS 16.0, *)
private struct SeriesPoint: Identifiable {
    let id = UUID()
    let date: Date        // начало месяца/квартала
    let series: Series
    let value: Double     // всегда в базовой валюте
}

struct ChartsView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        if #available(iOS 16.0, *) {
            ChartsScreen()
        } else {
            NavigationStack {
                VStack(spacing: 16) {
                    Text("Графики доступны на iOS 16 и выше.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .navigationTitle("Графики")
            }
        }
    }
}

@available(iOS 16.0, *)
private struct ChartsScreen: View {
    @EnvironmentObject var app: AppState

    // Настройки графика
    @State private var kind: ChartKind = .bars
    @State private var bucket: Bucket = .month
    @State private var range: RangeMonths = .m12
    @State private var showIncome = true
    @State private var showExpense = true
    @State private var showNet = true

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                controls

                Chart(allPointsFiltered) { p in
                    switch kind {
                    case .bars:
                        BarMark(
                            x: .value("Период", p.date, unit: xAxisUnit),
                            y: .value("Сумма", p.value)
                        )
                        .foregroundStyle(by: .value("Серия", p.series.rawValue))
                        .position(by: .value("Серия", p.series.rawValue))

                    case .lines:
                        LineMark(
                            x: .value("Период", p.date, unit: xAxisUnit),
                            y: .value("Сумма", p.value)
                        )
                        .foregroundStyle(by: .value("Серия", p.series.rawValue))
                        .interpolationMethod(.catmullRom)
                        PointMark(
                            x: .value("Период", p.date, unit: xAxisUnit),
                            y: .value("Сумма", p.value)
                        )
                        .foregroundStyle(by: .value("Серия", p.series.rawValue))
                    }
                }
                .chartXAxis {
                    switch bucket {
                    case .month:
                        AxisMarks(values: .stride(by: .month)) { value in
                            AxisGridLine()
                            AxisTick()
                            if let date = value.as(Date.self) {
                                AxisValueLabel(date, format: .dateTime.month(.abbreviated))
                            }
                        }
                    case .quarter:
                        AxisMarks(values: .stride(by: .quarter)) { value in
                            AxisGridLine()
                            AxisTick()
                            if let date = value.as(Date.self) {
                                AxisValueLabel(quarterLabel(date))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(minHeight: 280)

                footerSummary
            }
            .padding(.horizontal, 16)
            .navigationTitle("Графики")
        }
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 8) {
            HStack {
                Picker("Тип", selection: $kind) {
                    ForEach(ChartKind.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            HStack {
                Picker("Детализация", selection: $bucket) {
                    ForEach(Bucket.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                Picker("Период", selection: $range) {
                    ForEach(RangeMonths.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            HStack(spacing: 12) {
                Toggle("Доходы", isOn: $showIncome).toggleStyle(.switch)
                Toggle("Расходы", isOn: $showExpense).toggleStyle(.switch)
                Toggle("Итог", isOn: $showNet).toggleStyle(.switch)
            }
            .font(.subheadline)
        }
    }

    // MARK: - Data

    private var xAxisUnit: Calendar.Component {
        bucket == .month ? .month : .quarter
    }

    private var months: [Date] {
        let cal = Calendar.current
        let now = cal.date(from: cal.dateComponents([.year, .month], from: Date()))! // начало текущего месяца
        return (0..<range.rawValue).reversed().compactMap { i in
            cal.date(byAdding: .month, value: -i, to: now)
        }
    }

    private var quarters: [Date] {
        // начало кварталов за выбранный горизонт
        let cal = Calendar.current
        let m = months
        let starts = m.map { startOfQuarter(for: $0) }
        // уникальные, по порядку
        var uniq: [Date] = []
        for d in starts where uniq.last != d { uniq.append(d) }
        return uniq
    }

    private var allPointsFiltered: [SeriesPoint] {
        switch bucket {
        case .month:
            return pointsByMonth.filter { p in
                (p.series == .income && showIncome) ||
                (p.series == .expense && showExpense) ||
                (p.series == .net && showNet)
            }
        case .quarter:
            return pointsByQuarter.filter { p in
                (p.series == .income && showIncome) ||
                (p.series == .expense && showExpense) ||
                (p.series == .net && showNet)
            }
        }
    }

    private var pointsByMonth: [SeriesPoint] {
        months.flatMap { month in
            let income = monthlyIncomeBase(for: month)
            let expense = monthlyExpenseBase(for: month)
            let net = income - expense
            return [
                SeriesPoint(date: month, series: .income, value: income),
                SeriesPoint(date: month, series: .expense, value: expense),
                SeriesPoint(date: month, series: .net, value: net)
            ]
        }
    }

    private var pointsByQuarter: [SeriesPoint] {
        let cal = Calendar.current
        return quarters.flatMap { qStart in
            // квартал = 3 месяца, начиная с qStart
            let monthsInQ = (0..<3).compactMap { cal.date(byAdding: .month, value: $0, to: qStart) }
            let income = monthsInQ.reduce(0) { $0 + monthlyIncomeBase(for: $1) }
            let expense = monthsInQ.reduce(0) { $0 + monthlyExpenseBase(for: $1) }
            let net = income - expense
            return [
                SeriesPoint(date: qStart, series: .income, value: income),
                SeriesPoint(date: qStart, series: .expense, value: expense),
                SeriesPoint(date: qStart, series: .net, value: net)
            ]
        }
    }

    // MARK: - Calculations (в базовой валюте)

    private func monthlyIncomeBase(for month: Date) -> Double {
        let rec = app.totalNormalizedMonthlyRecurringIncome(for: month) // уже в базе (мы меняли AppState раньше)
        // разовые доходы в пределах месяца
        let cal = Calendar.current
        let oneOff: Decimal = app.incomes.reduce(0) { acc, i in
            guard case .oneOff(let d, _) = i.kind,
                  cal.isDate(d, equalTo: month, toGranularity: .month)
            else { return acc }
            return acc + app.toBase(Decimal(i.amount), from: i.currency)
        }
        return rec + NSDecimalNumber(decimal: oneOff).doubleValue
    }

    private func monthlyExpenseBase(for month: Date) -> Double {
        // плановые (рекуррентные + обязательные по долгам + запланированные записи)
        var total = app.plannedMonthlyExpense(for: month)
        // разовые расходы из массива Expense
        let cal = Calendar.current
        let oneOff: Decimal = app.expenses.reduce(0) { acc, e in
            guard case .oneOff(let d, _) = e.kind,
                  let d, cal.isDate(d, equalTo: month, toGranularity: .month)
            else { return acc }
            return acc + app.toBase(Decimal(e.amount), from: e.currency)
        }
        total += NSDecimalNumber(decimal: oneOff).doubleValue
        return total
    }

    // MARK: - Helpers

    private func startOfQuarter(for date: Date) -> Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: date)
        guard let month = comps.month, let year = comps.year else { return date }
        // 1–3 -> 1; 4–6 -> 4; 7–9 -> 7; 10–12 -> 10
        let qStartMonth = ((month - 1) / 3) * 3 + 1
        return cal.date(from: DateComponents(year: year, month: qStartMonth, day: 1)) ?? date
    }

    private func quarterLabel(_ date: Date) -> String {
        let cal = Calendar.current
        let m = cal.component(.month, from: date)
        let y = cal.component(.year, from: date)
        let q = ((m - 1) / 3) + 1
        return "Q\(q) \(y)"
    }

    private var footerSummary: some View {
        let last = months.last ?? Date()
        let income = monthlyIncomeBase(for: last)
        let expense = monthlyExpenseBase(for: last)
        let net = income - expense

        return HStack {
            Text("Текущий месяц:")
            Spacer()
            Text(app.formatMoney(income,  currency: app.baseCurrency)).monospacedDigit()
            Text("–")
            Text(app.formatMoney(expense, currency: app.baseCurrency)).monospacedDigit()
            Text("=")
            Text(app.formatMoney(net,     currency: app.baseCurrency))
                .foregroundStyle(net >= 0 ? .green : .red)
                .monospacedDigit()
        }
        .font(.footnote)
        .padding(.vertical, 4)
    }
}
