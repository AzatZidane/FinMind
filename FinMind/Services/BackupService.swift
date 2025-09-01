import Foundation
import SwiftUI
import UniformTypeIdentifiers

// Все твои модели должны быть Codable (Income/Expense/Debt/Goal уже такие в проекте)
struct BackupPayload: Codable {
    var createdAt: Date
    var incomes: [Income]
    var expenses: [Expense]
    var debts: [Debt]
    var goals: [Goal]
    // на будущее можно добавить версию схемы
    var schemaVersion: Int = 1
}

// FileDocument для .fileExporter / .fileImporter
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        guard let d = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = d
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

// Утилиты сериализации (вынесено сюда, чтобы не трогать Persistence)
enum BackupCodec {
    static func makeJSON(from app: AppState) throws -> Data {
        let payload = BackupPayload(
            createdAt: Date(),
            incomes: app.incomes,
            expenses: app.expenses,
            debts: app.debts,
            goals: app.goals
        )
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        return try enc.encode(payload)
    }

    static func applyJSON(_ data: Data, to app: AppState) throws {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let payload = try dec.decode(BackupPayload.self, from: data)

        // Заменяем состояние АТОМАРНО
        app.incomes = payload.incomes
        app.expenses = payload.expenses
        app.debts = payload.debts
        app.goals = payload.goals

        // Если у тебя есть ручное сохранение — дерни его
        // (автосейв через Combine у тебя уже настроен, но на всякий)
        app.forceSave()
    }
}
