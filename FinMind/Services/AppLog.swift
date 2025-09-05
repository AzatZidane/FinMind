import Foundation
import OSLog

/// Категории логов
enum AppLogCategory: String {
    case app, network, rates, metals, error
}

/// Файловый логгер + unified logging (OSLog)
final class AppLog {
    static let shared = AppLog()
    private init() {}

    // Включатель (общий с экраном Диагностики)
    private var isEnabled: Bool { UserDefaults.standard.bool(forKey: "diag.enabled") }

    // Очередь записи
    private let q = DispatchQueue(label: "fm.logger", qos: .utility)

    // Ротация: 512 КБ * 3 файла
    private let maxBytes: Int = 512 * 1024
    private let maxFiles: Int = 3

    private var logDir: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = dir.appendingPathComponent("Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }
    private var currentURL: URL { logDir.appendingPathComponent("finmind.log") }

    // Unified logging (Console.app)
    private let oslog = Logger(subsystem: "app.finmind", category: "general")

    // Публичные фасады
    static func i(_ cat: AppLogCategory, _ msg: String) { shared.write(cat, msg) }
    static func e(_ msg: String) { shared.write(.error, msg) }

    /// Прочитать «хвост» лога для UI
    func readTail(_ limitBytes: Int = 80_000) -> String {
        guard let data = try? Data(contentsOf: currentURL) else { return "" }
        let slice = data.count <= limitBytes ? data : data.suffix(limitBytes)
        return String(data: slice, encoding: String.Encoding.utf8) ?? ""
    }

    /// URL текущего файла (для шаринга)
    func currentFileURL() -> URL { currentURL }

    /// Очистка
    func clear() {
        try? FileManager.default.removeItem(at: currentURL)
    }

    // MARK: - Core
    private func write(_ category: AppLogCategory, _ msg: String) {
        // В системный лог
        oslog.log("\(category.rawValue): \(msg, privacy: .public)")

        guard isEnabled else { return }

        let line = "[\(timestamp())] [\(category.rawValue.uppercased())] \(msg)\n"
        let data = Data(line.utf8)

        q.async {
            // дописываем
            if FileManager.default.fileExists(atPath: self.currentURL.path) {
                if let fh = try? FileHandle(forWritingTo: self.currentURL) {
                    defer { try? fh.close() }
                    do {
                        try fh.seekToEnd()
                        try fh.write(contentsOf: data)
                    } catch {
                        // не даём логгеру «ронять» приложение
                    }
                }
            } else {
                try? data.write(to: self.currentURL)
            }
            // ротация
            self.rotateIfNeeded()
        }
    }

    private func rotateIfNeeded() {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: currentURL.path),
              let size = attrs[.size] as? NSNumber else { return }
        if size.intValue < maxBytes { return }

        // *.log -> *.1.log -> *.2.log
        for i in stride(from: maxFiles - 1, through: 1, by: -1) {
            let src = logDir.appendingPathComponent("finmind.\(i).log")
            let dst = logDir.appendingPathComponent("finmind.\(i+1).log")
            if FileManager.default.fileExists(atPath: dst.path) { try? FileManager.default.removeItem(at: dst) }
            if FileManager.default.fileExists(atPath: src.path) { try? FileManager.default.moveItem(at: src, to: dst) }
        }
        let first = logDir.appendingPathComponent("finmind.1.log")
        if FileManager.default.fileExists(atPath: first.path) { try? FileManager.default.removeItem(at: first) }
        try? FileManager.default.moveItem(at: currentURL, to: first)
        try? Data().write(to: currentURL)
    }

    private func timestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f.string(from: Date())
    }
}
