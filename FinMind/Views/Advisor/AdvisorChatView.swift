import SwiftUI

struct AdvisorChatView: View {
    @EnvironmentObject var app: AppState
    @StateObject private var vm = ChatVM()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(vm.messages.enumerated()), id: \.offset) { idx, msg in
                                bubble(for: msg).id(idx)
                            }
                            if vm.isStreaming { ProgressView().padding(.leading, 8) }
                        }
                        .padding(12)
                    }
                    .onChange(of: vm.messages.count) { _ in
                        withAnimation { proxy.scrollTo(vm.messages.count - 1, anchor: .bottom) }
                    }
                }

                Divider()

                HStack(spacing: 8) {
                    TextField("Спросите про бюджет, долги, подушку…", text: $vm.input, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...3)

                    Button {
                        Task { await vm.send(app: app) }
                    } label: {
                        Image(systemName: "paperplane.fill")
                    }
                    .disabled(vm.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isStreaming)
                }
                .padding(12)
            }
            .navigationTitle("Чат с советником")
        }
    }

    @ViewBuilder
    private func bubble(for m: ChatMessage) -> some View {
        HStack {
            if m.role == .assistant { Spacer() }
            Text(m.content)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10)
                    .fill(m.role == .assistant ? Color.secondary.opacity(0.15) : Color.accentColor.opacity(0.15)))
            if m.role == .user { Spacer() }
        }
    }
}

final class ChatVM: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var input = ""
    @Published var isStreaming = false

    private let service = OpenAIChatService()

    /// Собираем system-prompt из AppState
    private func systemMessage(app: AppState) -> ChatMessage {
        var text = "Вы — финансовый помощник. Вот данные пользователя:\n"

        if !app.incomes.isEmpty {
            text += "\nДоходы:"
            for i in app.incomes {
                text += "\n- \(i.name): \(i.amount)"
            }
        }
        if !app.expenses.isEmpty {
            text += "\nРасходы:"
            for e in app.expenses {
                text += "\n- \(e.name): \(e.amount)"
            }
        }
        if !app.debts.isEmpty {
            text += "\nДолги:"
            for d in app.debts {
                text += "\n- \(d.name)"
            }
        }
        if !app.goals.isEmpty {
            text += "\nЦели:"
            for g in app.goals {
                text += "\n- \(g.name): \(g.targetAmount)"
            }
        }
        return .init(role: .system, content: text)
    }

    @MainActor
    func send(app: AppState) async {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming else { return }
        input = ""

        let userMsg = ChatMessage(role: .user, content: text)

        // полный контекст: system (данные) + история + новый вопрос
        var context: [ChatMessage] = [systemMessage(app: app)] + messages + [userMsg]
        messages.append(userMsg)

        isStreaming = true
        messages.append(.init(role: .assistant, content: ""))

        do {
            try await service.stream(messages: context, onDelta: { [weak self] token in
                Task { @MainActor in
                    guard let self = self else { return }
                    if var last = self.messages.popLast() {
                        last = .init(role: .assistant, content: last.content + token)
                        self.messages.append(last)
                    }
                }
            }, onFinish: { [weak self] in
                Task { @MainActor in self?.isStreaming = false }
            })
        } catch {
            await MainActor.run {
                self.isStreaming = false
                self.messages.append(.init(role: .assistant, content: "Ошибка: \(error.localizedDescription)"))
            }
        }
    }
}
