import Foundation

enum QualityIssue: Hashable, Identifiable {
    case kepekatan
    case phAir
    case keduanya

    var id: Self {
        self
    }

    func combining(with other: QualityIssue) -> QualityIssue {
        if self == other || self == .keduanya {
            return self
        }
        if other == .keduanya {
            return .keduanya
        }
        return .keduanya
    }
}

struct QualityAlert: Equatable {
    let issue: QualityIssue
    let message: String
}
