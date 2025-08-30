import Foundation

struct Persistence {
    static let shared = Persistence()
    
    private var fileURL: URL {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("finmind.json")
    }
    
    func load() -> AppState {
        do {
            let data = try Data(contentsOf: fileURL)
            let state = try JSONDecoder().decode(AppState.self, from: data)
            return state
        } catch {
            return AppState()
        }
    }
    
    func save(_ state: AppState) throws {
        let data = try JSONEncoder().encode(state)
        try data.write(to: fileURL, options: .atomic)
    }
}
