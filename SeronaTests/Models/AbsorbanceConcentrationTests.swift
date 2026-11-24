import Foundation
@testable import Serona
import Testing

@Suite("Absorbance concentration")
@MainActor
struct AbsorbanceConcentrationTests {
    private let clean = [Double](repeating: 0.4, count: 8)

    private func reading(ratio: Double) -> ColorMeasurement {
        let count = UInt16((ratio * 1000).rounded())
        return ColorMeasurement(
            visibleAverage: 0,
            clear: 1000,
            nir: 0,
            channels: [UInt16](repeating: count, count: 8),
            clearFirst: 1000
        )
    }

    @Test("Absorbance is -log10 of the mean transmittance when the channels agree")
    func absorbanceOfEvenChannels() throws {
        let absorbance = try #require(ColorMeasurement.absorbance(
            ratios: [Double](repeating: 0.2, count: 8),
            cleanRatios: clean
        ))

        #expect(abs(absorbance - -log10(0.5)) < 1e-9)
    }

    @Test("Absorbance uses the lowest transmittance once the channels differ by 0.08 or more")
    func absorbanceOfUnevenChannels() throws {
        var ratios = [Double](repeating: 0.36, count: 8)
        ratios[4] = 0.2

        let absorbance = try #require(ColorMeasurement.absorbance(ratios: ratios, cleanRatios: clean))

        #expect(abs(absorbance - -log10(0.5)) < 1e-9)
    }

    @Test("Absorbance averages the channels when they differ by less than 0.08")
    func absorbanceAveragesCloseChannels() throws {
        var ratios = [Double](repeating: 0.2, count: 8)
        ratios[0] = 0.208

        let absorbance = try #require(ColorMeasurement.absorbance(ratios: ratios, cleanRatios: clean))
        let transmittances = ratios.map { $0 / 0.4 }
        let mean = transmittances.reduce(0, +) / Double(transmittances.count)

        #expect(abs(absorbance - -log10(mean)) < 1e-9)
    }

    @Test("Absorbance is nil without matching, usable data")
    func absorbanceNeedsData() {
        #expect(ColorMeasurement.absorbance(ratios: [], cleanRatios: []) == nil)
        #expect(ColorMeasurement.absorbance(ratios: [0.2, 0.2], cleanRatios: clean) == nil)
        let dark = [Double](repeating: 0, count: 8)
        #expect(ColorMeasurement.absorbance(ratios: dark, cleanRatios: clean) == nil)
    }

    @Test("A channel without clean-water signal counts as T = 1 instead of being skipped")
    func cleanChannelWithoutSignalCountsAsFullTransmittance() throws {
        let even = [Double](repeating: 0.2, count: 8)
        var cleanWithGap = clean
        cleanWithGap[3] = 0

        let absorbance = try #require(ColorMeasurement.absorbance(ratios: even, cleanRatios: cleanWithGap))
        #expect(abs(absorbance - -log10(0.5)) < 1e-9)

        let dark = [Double](repeating: 0, count: 8)
        let none = try #require(ColorMeasurement.absorbance(ratios: even, cleanRatios: dark))
        #expect(abs(none) < 1e-9)
    }

    @Test("The baseline reads 100% and less dye reads lower")
    func concentrationFollowsDye() throws {
        let baseline = [Double](repeating: 0.2, count: 8)
        let atBaseline = try #require(reading(ratio: 0.2).concentration(relativeToRatios: baseline, cleanRatios: clean))

        let lessDye = try #require(reading(ratio: 0.3).concentration(relativeToRatios: baseline, cleanRatios: clean))

        #expect(abs(atBaseline - 100) < 1e-9)
        #expect(abs(lessDye - log10(1 / 0.75) / log10(1 / 0.5) * 100) < 1e-9)
        #expect(lessDye < 100)
    }

    @Test("Concentration is nil without a baseline that absorbs, or without channels")
    func concentrationNeedsAbsorbingBaseline() {
        let noChannels = ColorMeasurement(visibleAverage: 1, clear: 1000, nir: 0)

        #expect(noChannels.concentration(relativeToRatios: clean, cleanRatios: clean) == nil)

        #expect(reading(ratio: 0.3).concentration(relativeToRatios: clean, cleanRatios: clean) == nil)
    }
}
