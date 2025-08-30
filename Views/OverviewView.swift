import SwiftUI

struct OverviewView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("Добро пожаловать в FinMind")
                    .font(.title3).fontWeight(.semibold)
                Text("Дашборд появится здесь: доходы, расходы, цели.")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("Обзор")
        }
    }
}

#Preview { OverviewView() }
