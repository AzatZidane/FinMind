import SwiftUI

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
                Text(g.name)
                Text("дедлайн: \(g.deadline.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(g.targetAmount.asMoney)  // ← форматированная сумма
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
