// Views/PlanView.swift
import SwiftUI

struct PlanView: View {
    @EnvironmentObject var app: AppState

    private var result: PlanResult {
        PlanEngine.makePlan(app: app)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Свободно в месяц") {
                    Text(result.sdp.moneyString)
                        .font(.title.bold())
                        .monospacedDigit()
                }

                Section("Распределение СДП") {
                    ForEach(result.allocations) { alloc in
                        HStack {
                            Text(alloc.kind.rawValue)
                            Spacer()
                            Text(alloc.amount.moneyString).monospacedDigit()
                        }
                        if let r = alloc.rationale {
                            Text(r).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }

                if !result.notes.isEmpty {
                    Section("Заметки") {
                        ForEach(result.notes, id: \.self) { Text($0) }
                    }
                }
            }
            .navigationTitle("План")
        }
    }
}

#Preview {
    PlanView().environmentObject(AppState())
}
