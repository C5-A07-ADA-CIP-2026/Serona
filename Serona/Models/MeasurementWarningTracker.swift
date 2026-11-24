import Foundation

nonisolated struct MeasurementWarningTracker {
    private var hasWarnedAboutLowConcentration = false

    mutating func concentrationWarning(for concentration: Double, limit: Double) -> String? {
        guard concentration < limit else {
            hasWarnedAboutLowConcentration = false
            return nil
        }
        guard !hasWarnedAboutLowConcentration else { return nil }
        hasWarnedAboutLowConcentration = true
        return Self.concentrationMessage(limit: limit)
    }

    static func concentrationMessage(limit: Double) -> String {
        "Kepekatan warna saat ini di bawah \(format(limit))%. "
            + "Tambahkan 10 gram pewarna untuk menjaga kualitas dan ketajaman warna batik."
    }

    static func waterPHMessage(limit: Double) -> String {
        "pH air saat ini di bawah \(format(limit)). "
            + "Tambahkan 10 gram soda abu untuk menjaga kualitas dan ketajaman warna batik."
    }

    static let bothMessage = "pH air dan kepekatan warna saat ini berada di bawah batas aman yang ditentukan. "
        + "Tindakan perbaikan disarankan agar hasil optimal."

    static func waterPHWarning(for waterPH: Double, limit: Double) -> String? {
        guard waterPH < limit else { return nil }
        return waterPHMessage(limit: limit)
    }

    private static func format(_ value: Double) -> String {
        String(format: "%g", value)
    }

    mutating func reset() {
        hasWarnedAboutLowConcentration = false
    }
}
