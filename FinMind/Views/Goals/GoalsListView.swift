import SwiftUI
import Foundation

struct GoalsListView: View {
    @EnvironmentObject var app: AppState
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            List {
                if app.goals.isEmpty {
                    Section { Text("Целей пока нет").foregroundStyle(.secondary) }
                } else {
                    Section("ЦЕЛИ") {
                        ForEach(Array(app.goals.enumerated()), id: \.offset) { _, goal in
                            row(goal)
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("Цели")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddGoalView().environmentObject(app)
            }
        }
    }

    @ViewBuilder
    private func row(_ g: Goal) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(g.name) // благодаря NameCompat работает как title
                if let deadline = g.deadline {
                    Text(deadline, format: Date.FormatStyle(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Без срока")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            Text(app.formatMoney(g.targetAmount, currency: g.currency))
                .font(.headline.monospacedDigit())
        }
    }

    private func delete(at offsets: IndexSet) {
        app.goals.remove(atOffsets: offsets)
    }
}

#Preview {
    GoalsListView().environmentObject(AppState())
}
