//
//  ColorMeasurementTests.swift
//  SeronaTests
//

import Foundation
@testable import Serona
import Testing

@Suite("Color measurement concentration")
@MainActor
struct ColorMeasurementTests {
    private let measurement = ColorMeasurement(visibleAverage: 735, clear: 1200, nir: 200)

    @Test("Concentration is the percentage of the baseline")
    func concentrationRelativeToBaseline() {
        #expect(measurement.concentration(relativeTo: 1000) == 73.5)
    }

    @Test("Concentration is nil without a positive baseline")
    func concentrationNeedsPositiveBaseline() {
        #expect(measurement.concentration(relativeTo: 0) == nil)
        #expect(measurement.concentration(relativeTo: -5) == nil)
    }

    @Test("Formatted concentration uses one decimal and falls back to 0.0%")
    func formattedConcentration() {
        #expect(measurement.formattedConcentration(relativeTo: 1000) == "73.5%")
        #expect(measurement.formattedConcentration(relativeTo: 735) == "100.0%")
        #expect(measurement.formattedConcentration(relativeTo: 0) == "0.0%")
    }

    // MARK: - Per-channel ratios against clear

    /// F1-F4 are read with `clearFirst`, F5-F8 with `clear`.
    private func channelReading(
        _ channels: [UInt16]? = [100, 200, 300, 400, 100, 200, 300, 400],
        clearFirst: UInt16? = 1000,
        clear: UInt16 = 500
    ) -> ColorMeasurement {
        ColorMeasurement(visibleAverage: 250, clear: clear, nir: 10, channels: channels, clearFirst: clearFirst)
    }

    @Test("Each channel is divided by the clear of the cycle that read it")
    func channelRatios() {
        let ratios = channelReading().channelRatios

        #expect(ratios == [0.1, 0.2, 0.3, 0.4, 0.2, 0.4, 0.6, 0.8])
    }

    @Test("There are no ratios without 8 channels or a positive clear")
    func channelRatiosNeedCompleteData() {
        #expect(channelReading(nil).channelRatios == nil)
        #expect(channelReading([1, 2, 3]).channelRatios == nil)
        #expect(channelReading(clearFirst: nil).channelRatios == nil)
        #expect(channelReading(clearFirst: 0).channelRatios == nil)
        #expect(channelReading(clear: 0).channelRatios == nil)
    }

    @Test("Concentration is the lowest channel transmittance against the baseline ratios")
    func concentrationFromMostAbsorbedChannel() {
        let baseline = [0.1, 0.2, 0.3, 0.4, 0.2, 0.4, 0.6, 0.8]
        // F5 drops to 0.144 (72% of 0.2); every other channel is unchanged.
        let darker = ColorMeasurement(
            visibleAverage: 250,
            clear: 500,
            nir: 10,
            channels: [100, 200, 300, 400, 72, 200, 300, 400],
            clearFirst: 1000
        )

        #expect(darker.channelRatios?[4] == 0.144)
        let percent = darker.concentration(relativeToRatios: baseline)
        #expect(percent != nil)
        #expect(abs((percent ?? 0) - 72) < 0.0001)
        #expect(channelReading().concentration(relativeToRatios: baseline) == 100)
    }

    @Test("Concentration from ratios is nil without channels, with a wrong baseline size, or an empty baseline")
    func concentrationFromRatiosNeedsData() {
        let baseline = [0.1, 0.2, 0.3, 0.4, 0.2, 0.4, 0.6, 0.8]

        #expect(channelReading(nil).concentration(relativeToRatios: baseline) == nil)
        #expect(channelReading().concentration(relativeToRatios: [0.1, 0.2]) == nil)
        #expect(channelReading().concentration(relativeToRatios: [Double](repeating: 0, count: 8)) == nil)
    }

    @Test("A channel with no baseline signal is skipped")
    func zeroBaselineChannelIsSkipped() {
        let baseline = [0, 0.2, 0.3, 0.4, 0.2, 0.4, 0.6, 0.8]

        #expect(channelReading().concentration(relativeToRatios: baseline) == 100)
    }

    @Test("The channels and the first clear are decoded from the BLE payload and optional")
    func decodesChannels() throws {
        let with = Data(
            #"{"visibleAverage":250.0,"clear":500,"nir":10,"clear1":1000,"channels":[1,2,3,4,5,6,7,8]}"#.utf8
        )
        let without = Data(#"{"visibleAverage":250.0,"clear":500,"nir":10}"#.utf8)

        let decoded = try JSONDecoder().decode(ColorMeasurement.self, from: with)
        #expect(decoded.channels == [1, 2, 3, 4, 5, 6, 7, 8])
        #expect(decoded.clearFirst == 1000)
        #expect(try JSONDecoder().decode(ColorMeasurement.self, from: without).channels == nil)
    }
}
