import Foundation

/// То, что пишем на диск
private struct ChatTranscript: Codable {
    var messages: [ChatMessage]
    var updatedAt: Date
}

/// Простое хранилище истории чата
final class ChatStorage {
    static let shared = ChatStorage()
    private init() {}

    // .../Application Support/FinMind/advisor_chat.json
    private var fileURL: URL {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("FinMind", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("advisor_chat.json")
    }

    /// Читаем историю. На всякий случай игнорируем .system сообщения.
    func load() -> [ChatMessage] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        if let t = try? JSONDecoder().decode(ChatTranscript.self, from: data) {
            return t.messages.filter { $0.role != .system }
        }
        return []
    }

    /// Сохраняем историю (без .system)
    func save(_ messages: [ChatMessage]) {
        let t = ChatTranscript(messages: messages.filter { $0.role != .system },
                               updatedAt: Date())
        if let data = try? JSONEncoder().encode(t) {
            try? data.write(to: fileURL, options: [.atomic])
        }
    }

    func clear() { save([]) }
}
