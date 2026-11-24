import Foundation

struct ProyekMeasurement: Identifiable, Equatable {
    let id: String
    let title: String
    let value: String
    let isCurrent: Bool
}

struct ProyekColorMeasurements: Equatable {
    private static let unknownValue = "—"

    let colorConcentrationLimit: Double
    let waterPHLimit: Double
    let initial: [ProyekMeasurement]
    let current: [ProyekMeasurement]

    init(colorConcentrationLimit: Double, waterPHLimit: Double, initialWaterPH: Double? = nil) {
        self.init(
            colorConcentrationLimit: colorConcentrationLimit,
            waterPHLimit: waterPHLimit,
            initial: [
                ProyekMeasurement(
                    id: "initial-color-concentration",
                    title: "Kepekatan Warna Awal",
                    value: "100%",
                    isCurrent: false
                ),
                ProyekMeasurement(
                    id: "color-concentration-limit",
                    title: "Batas Kepekatan Warna",
                    value: "\(Self.format(colorConcentrationLimit))%",
                    isCurrent: false
                ),
                ProyekMeasurement(
                    id: "initial-water-ph",
                    title: "pH Air Awal",
                    value: initialWaterPH.map(Self.format) ?? Self.unknownValue,
                    isCurrent: false
                ),
                ProyekMeasurement(
                    id: "water-ph-limit",
                    title: "Batas pH",
                    value: Self.format(waterPHLimit),
                    isCurrent: false
                ),
            ],
            current: [
                ProyekMeasurement(
                    id: "current-color-concentration",
                    title: "Kepekatan Warna Sekarang",
                    value: Self.unknownValue,
                    isCurrent: true
                ),
                ProyekMeasurement(
                    id: "current-water-ph",
                    title: "pH Air Sekarang",
                    value: Self.unknownValue,
                    isCurrent: true
                ),
            ]
        )
    }

    private init(
        colorConcentrationLimit: Double,
        waterPHLimit: Double,
        initial: [ProyekMeasurement],
        current: [ProyekMeasurement]
    ) {
        self.colorConcentrationLimit = colorConcentrationLimit
        self.waterPHLimit = waterPHLimit
        self.initial = initial
        self.current = current
    }

    static func format(_ value: Double) -> String {
        String(format: "%g", value)
    }

    func withCurrentConcentration(
        _ measurement: ColorMeasurement,
        relativeTo baseline: Double
    ) -> ProyekColorMeasurements {
        var updatedCurrent = current
        guard let index = updatedCurrent.firstIndex(where: { $0.id == "current-color-concentration" }) else {
            return self
        }

        updatedCurrent[index] = ProyekMeasurement(
            id: updatedCurrent[index].id,
            title: updatedCurrent[index].title,
            value: measurement.formattedConcentration(relativeTo: baseline),
            isCurrent: updatedCurrent[index].isCurrent
        )
        return replacingCurrent(updatedCurrent)
    }

    func withCurrentConcentration(percent: Double) -> ProyekColorMeasurements {
        var updatedCurrent = current
        guard let index = updatedCurrent.firstIndex(where: { $0.id == "current-color-concentration" }) else {
            return self
        }

        updatedCurrent[index] = ProyekMeasurement(
            id: updatedCurrent[index].id,
            title: updatedCurrent[index].title,
            value: ColorMeasurement.formatPercent(percent),
            isCurrent: updatedCurrent[index].isCurrent
        )
        return replacingCurrent(updatedCurrent)
    }

    func withCurrentWaterPH(_ waterPH: Double?) -> ProyekColorMeasurements {
        var updatedCurrent = current
        guard let index = updatedCurrent.firstIndex(where: { $0.id == "current-water-ph" }) else {
            return self
        }

        updatedCurrent[index] = ProyekMeasurement(
            id: updatedCurrent[index].id,
            title: updatedCurrent[index].title,
            value: waterPH.map(Self.format) ?? Self.unknownValue,
            isCurrent: updatedCurrent[index].isCurrent
        )
        return replacingCurrent(updatedCurrent)
    }

    func withoutCurrentConcentration() -> ProyekColorMeasurements {
        var updatedCurrent = current
        guard let index = updatedCurrent.firstIndex(where: { $0.id == "current-color-concentration" }) else {
            return self
        }

        updatedCurrent[index] = ProyekMeasurement(
            id: updatedCurrent[index].id,
            title: updatedCurrent[index].title,
            value: Self.unknownValue,
            isCurrent: updatedCurrent[index].isCurrent
        )
        return replacingCurrent(updatedCurrent)
    }

    func withInitialWaterPH(_ waterPH: Double?) -> ProyekColorMeasurements {
        replacingInitial(id: "initial-water-ph", value: waterPH.map(Self.format) ?? Self.unknownValue)
    }

    func withInitialConcentration(isSet: Bool) -> ProyekColorMeasurements {
        replacingInitial(id: "initial-color-concentration", value: isSet ? "100%" : Self.unknownValue)
    }

    private func replacingInitial(id: String, value: String) -> ProyekColorMeasurements {
        var updatedInitial = initial
        guard let index = updatedInitial.firstIndex(where: { $0.id == id }) else {
            return self
        }

        updatedInitial[index] = ProyekMeasurement(
            id: id,
            title: updatedInitial[index].title,
            value: value,
            isCurrent: updatedInitial[index].isCurrent
        )
        return ProyekColorMeasurements(
            colorConcentrationLimit: colorConcentrationLimit,
            waterPHLimit: waterPHLimit,
            initial: updatedInitial,
            current: current
        )
    }

    private func replacingCurrent(_ current: [ProyekMeasurement]) -> ProyekColorMeasurements {
        ProyekColorMeasurements(
            colorConcentrationLimit: colorConcentrationLimit,
            waterPHLimit: waterPHLimit,
            initial: initial,
            current: current
        )
    }

    func concentration(
        for measurement: ColorMeasurement,
        relativeTo baseline: Double
    ) -> Double? {
        measurement.concentration(relativeTo: baseline)
    }

    var displayedMeasurements: [ProyekMeasurement] {
        guard current.count >= 2, initial.count >= 4 else {
            return initial
        }

        return [
            current[0],
            initial[0],
            initial[1],
            current[1],
            initial[2],
            initial[3],
        ]
    }
}
