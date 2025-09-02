import Foundation

// Совместимость со старыми вью: .name <-> .title
extension Income {
    var name: String {
        get { title }
        set { title = newValue }
    }
}

extension Expense {
    var name: String {
        get { title }
        set { title = newValue }
    }
}

extension Goal {
    var name: String {
        get { title }
        set { title = newValue }
    }
}
