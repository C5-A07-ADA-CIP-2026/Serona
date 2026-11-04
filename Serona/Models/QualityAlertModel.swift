//
//  QualityAlertModel.swift
//  Serona
//

import Foundation

/// What fell below its limit: the color concentration, the water pH, or both.
enum QualityIssue: Hashable, Identifiable {
    case kepekatan
    case phAir
    case keduanya

    var id: Self {
        self
    }

    /// Merge current issue with a newly detected issue if current issue not done yet
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

/// The "Kualitas Larutan Menurun" sheet: what is low and what to do about it.
struct QualityAlert: Equatable {
    let issue: QualityIssue
    let message: String
}
