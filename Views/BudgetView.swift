import SwiftUI

struct BudgetView: View {
    @State private var showIncomes = true
    @State private var showExpenses = true
    @State private var showDebts = true
    @State private var showGoals = true

    var body: some View {
        NavigationStack {
            List {
                // Доходы
                Section {
                    if showIncomes {
                        Text("Здесь будут доходы")
                    }
                } header: {
                    HStack {
                        Text("Доходы")
                        Spacer()
                        Button(action: { showIncomes.toggle() }) {
                            Image(systemName: showIncomes ? "chevron.down" : "chevron.right")
                        }
                        Button(action: {
                            // TODO: добавить экран добавления дохода
                        }) {
                            Image(systemName: "plus.circle")
                        }
                    }
                }

                // Расходы
                Section {
                    if showExpenses {
                        Text("Здесь будут расходы")
                    }
                } header: {
                    HStack {
                        Text("Расходы")
                        Spacer()
                        Button(action: { showExpenses.toggle() }) {
                            Image(systemName: showExpenses ? "chevron.down" : "chevron.right")
                        }
                        Button(action: {
                            // TODO: добавить экран добавления расхода
                        }) {
                            Image(systemName: "plus.circle")
                        }
                    }
                }

                // Долги
                Section {
                    if showDebts {
                        Text("Здесь будут кредиты/долги")
                    }
                } header: {
                    HStack {
                        Text("Долги")
                        Spacer()
                        Button(action: { showDebts.toggle() }) {
                            Image(systemName: showDebts ? "chevron.down" : "chevron.right")
                        }
                        Button(action: {
                            // TODO: добавить экран добавления долга
                        }) {
                            Image(systemName: "plus.circle")
                        }
                    }
                }

                // Цели
                Section {
                    if showGoals {
                        Text("Здесь будут цели")
                    }
                } header: {
                    HStack {
                        Text("Цели")
                        Spacer()
                        Button(action: { showGoals.toggle() }) {
                            Image(systemName: showGoals ? "chevron.down" : "chevron.right")
                        }
                        Button(action: {
                            // TODO: добавить экран добавления цели
                        }) {
                            Image(systemName: "plus.circle")
                        }
                    }
                }
            }
            .navigationTitle("Данные")
            .toolbar {
                Button("Календарь") {
                    // TODO: переход на экран календаря
                }
            }
        }
    }
}

#Preview {
    BudgetView()
}
