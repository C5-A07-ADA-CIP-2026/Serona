@testable import Serona
import Testing

@Suite("Proyek color measurements")
@MainActor
struct ProyekModelTests {
    @Test("Builds rows from recipe limits")
    func buildsRowsFromLimits() {
        let measurements = ProyekColorMeasurements(colorConcentrationLimit: 80, waterPHLimit: 7)

        #expect(measurements.initial.map(\.title) == [
            "Kepekatan Warna Awal",
            "Batas Kepekatan Warna",
            "pH Air Awal",
            "Batas pH",
        ])
        #expect(measurements.initial[0].value == "100%")
        #expect(measurements.initial[1].value == "80%")
        #expect(measurements.initial[2].value == "—")
        #expect(measurements.initial[3].value == "7")
        #expect(measurements.colorConcentrationLimit == 80)
        #expect(measurements.waterPHLimit == 7)
    }

    @Test("Formats fractional limits without trailing zeros")
    func formatsFractionalLimits() {
        let measurements = ProyekColorMeasurements(colorConcentrationLimit: 87.5, waterPHLimit: 7.5)

        #expect(measurements.initial[1].value == "87.5%")
        #expect(measurements.initial[3].value == "7.5")
    }

    @Test("Shows initial water pH when known")
    func showsInitialWaterPHWhenKnown() {
        let measurements = ProyekColorMeasurements(
            colorConcentrationLimit: 80,
            waterPHLimit: 7,
            initialWaterPH: 11
        )

        #expect(measurements.initial[2].value == "11")
    }

    @Test("Displays current measurements before their initial values")
    func displayedMeasurementsOrderUnchanged() {
        let measurements = ProyekColorMeasurements(colorConcentrationLimit: 80, waterPHLimit: 7)

        #expect(measurements.displayedMeasurements.map(\.title) == [
            "Kepekatan Warna Sekarang",
            "Kepekatan Warna Awal",
            "Batas Kepekatan Warna",
            "pH Air Sekarang",
            "pH Air Awal",
            "Batas pH",
        ])
    }

    @Test("Current readings are unknown until measured")
    func currentReadingsStartUnknown() {
        let measurements = ProyekColorMeasurements(colorConcentrationLimit: 80, waterPHLimit: 7)

        #expect(measurements.current.map(\.value) == ["—", "—"])
    }

    @Test("Calculates current concentration relative to initial sensor reading")
    func currentConcentrationRelativeToBaseline() {
        let measurements = ProyekColorMeasurements(colorConcentrationLimit: 80, waterPHLimit: 7)
            .withCurrentConcentration(
                ColorMeasurement(visibleAverage: 735, clear: 1200, nir: 200),
                relativeTo: 1000
            )

        #expect(measurements.initial.first?.value == "100%")
        #expect(measurements.current.first?.value == "73.5%")
        #expect(measurements.colorConcentrationLimit == 80)
        #expect(measurements.waterPHLimit == 7)
    }

    @Test("Updates and clears the current water pH row")
    func withCurrentWaterPH() {
        let measurements = ProyekColorMeasurements(colorConcentrationLimit: 80, waterPHLimit: 7)
            .withCurrentWaterPH(6.9)

        #expect(measurements.current[1].value == "6.9")
        #expect(measurements.withCurrentWaterPH(nil).current[1].value == "—")
    }
}
