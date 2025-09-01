import SwiftUI

struct AdvisorChatView: View {
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
                    Menu {
                        Toggle(isOn: $vm.useStreaming) { Text("Стриминг ответа") }
                        Picker("Модель", selection: $vm.model) {
                            Text("gpt-4o-mini").tag("gpt-4o-mini")
                            Text("gpt-4o").tag("gpt-4o")
                            Text("gpt-4.1").tag("gpt-4.1")
                        }
                    } label: { Image(systemName: "slider.horizontal.3") }

                    Button {
                        Task { await vm.send() }
                    } label: { Image(systemName: "paperplane.fill") }
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
    @Published var messages: [ChatMessage] = [
        .init(role: .system, content: "Вы — бережный русскоязычный финансовый помощник. Давайте рекомендации без категоричных обещаний. Если нужен точный расчёт, просите входные данные. Избегайте персональных юридических/налоговых советов.")
    ]
    @Published var input = ""
    @Published var isStreaming = false
    @Published var useStreaming = true
    @Published var model = "gpt-4o-mini"

    private let service = OpenAIChatService()

    @MainActor
    func send() async {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming else { return }
        input = ""
        service.model = model

        messages.append(.init(role: .user, content: text))
        let ctx = messages

        if useStreaming {
            isStreaming = true
            messages.append(.init(role: .assistant, content: ""))
            do {
                try await service.stream(messages: ctx, onDelta: { [weak self] token in
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
        } else {
            do {
                let reply = try await service.complete(messages: ctx)
                messages.append(.init(role: .assistant, content: reply))
            } catch {
                messages.append(.init(role: .assistant, content: "Ошибка: \(error.localizedDescription)"))
            }
        }
    }
}
