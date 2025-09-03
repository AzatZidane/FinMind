import Foundation

final class BackupService {
    static let shared = BackupService()

    // Готовим кодировщики
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private func makeDecoderISO() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    private func makeDecoderDefault() -> JSONDecoder {
        JSONDecoder() // на случай старых бэкапов без ISO‑дат
    }

    // Экспорт всего AppState в JSON
    func makeJSON(from app: AppState) throws -> Data {
        try encoder.encode(app)
    }

    // Импорт JSON в существующий AppState
    func restore(from data: Data, into app: AppState) throws {
        // Сначала пробуем ISO‑8601, затем дефолт
        let decoded: AppState
        do {
            decoded = try makeDecoderISO().decode(AppState.self, from: data)
        } catch {
            decoded = try makeDecoderDefault().decode(AppState.self, from: data)
        }

        // Переносим данные (перезаписываем поля)
        app.incomes      = decoded.incomes
        app.expenses     = decoded.expenses
        app.debts        = decoded.debts
        app.goals        = decoded.goals
        app.dailyEntries = decoded.dailyEntries
        app.firstUseAt   = decoded.firstUseAt

        app.baseCurrency = decoded.baseCurrency
        app.reserves     = decoded.reserves
        app.rates        = decoded.rates

        app.useCents     = decoded.useCents
        app.appearance   = decoded.appearance

        app.forceSave()
    }
}
