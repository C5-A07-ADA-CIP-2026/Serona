//
//  ProyekDetailChannelConcentrationTests.swift
//  SeronaTests
//

import Foundation
@testable import Serona
import Testing

/// The app, not the device, computes the concentration: the absorbance of the dominant (most absorbed) channel
/// against the fixed clean water, as a share of the absorbance of the ratios saved with the initial color.
@MainActor
struct ProyekDetailChannelConcentrationTests {
    private func makeProyek() -> Proyek {
        Proyek(nama: "Seragam RT 5", perangkatNama: "ESP 32", resep: .sample(batasKepekatan: 80), jumlahKain: 3)
    }

    /// All channels at 200 against a clear of 1000, except F7 (`channel7`, default 200), the most absorbed one
    /// against the clean water.
    private func reading(channel7: UInt16 = 200, average: Double = 1000, channels: Bool = true) -> ColorMeasurement {
        ColorMeasurement(
            visibleAverage: average,
            clear: 1000,
            nir: 10,
            waterPH: 11,
            channels: channels ? [200, 200, 200, 200, 200, 200, channel7, 200] : nil,
            clearFirst: channels ? 1000 : nil
        )
    }

    private func makeLive(
        proyek: Proyek? = nil,
        initial: ColorMeasurement
    ) async -> (ProyekDetailViewModel, AsyncStream<ColorMeasurement>.Continuation) {
        let (updates, liveReadings) = AsyncStream<ColorMeasurement>.makeStream()
        let viewModel = ProyekDetailViewModel(
            proyek: proyek ?? makeProyek(),
            service: StubDeviceConnectionService(initial: initial, liveUpdates: updates)
        )
        await viewModel.mulaiPindai()
        return (viewModel, liveReadings)
    }

    @Test("Setting the initial color saves the channel ratios of that reading")
    func setSavesRatios() async {
        let proyek = makeProyek()
        let (viewModel, _) = await makeLive(proyek: proyek, initial: reading())

        #expect(viewModel.tetapkanWarnaAwal(in: RecordingModelPersistence()))

        #expect(proyek.rasioAwal == [0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2])
        #expect(viewModel.latestConcentration == 100)
    }

    /// Absorbance of `ratios` as a percentage of the baseline's, against the fixed clean water.
    private func expectedConcentration(of ratios: [Double], baseline: [Double]) -> Double {
        let clean = ProyekDetailViewModel.defaultCleanWaterRatios
        let now = ColorMeasurement.absorbance(ratios: ratios, cleanRatios: clean) ?? 0
        let initial = ColorMeasurement.absorbance(ratios: baseline, cleanRatios: clean) ?? 1
        return now / initial * 100
    }

    private static let baselineRatios = [Double](repeating: 0.2, count: 8)
    /// F7 lightens to 0.4, so F8 becomes the most absorbed channel.
    private static let lighterRatios: [Double] = [0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.4, 0.2]

    @Test("Afterwards the concentration follows the most absorbed channel, not the visible average")
    func concentrationUsesChannels() async {
        let (viewModel, liveReadings) = await makeLive(initial: reading())
        viewModel.tetapkanWarnaAwal(in: RecordingModelPersistence())

        // The visible average barely moves (990 of 1000) while the dominant channel changes.
        liveReadings.yield(reading(channel7: 400, average: 990))
        let expected = expectedConcentration(of: Self.lighterRatios, baseline: Self.baselineRatios)
        let applied = await waitUntil { viewModel.latestConcentration != 100 }

        #expect(applied)
        #expect(expected < 100)
        #expect(abs((viewModel.latestConcentration ?? 0) - expected) < 0.0001)
        #expect(viewModel.measurements.current[0].value == ColorMeasurement.formatPercent(expected))
    }

    @Test("Without channels in the readings it falls back to the visible average")
    func fallsBackToVisibleAverage() async {
        let proyek = makeProyek()
        let (viewModel, liveReadings) = await makeLive(proyek: proyek, initial: reading(channels: false))
        viewModel.tetapkanWarnaAwal(in: RecordingModelPersistence())

        liveReadings.yield(reading(average: 900, channels: false))
        let applied = await waitUntil { viewModel.latestConcentration == 90 }

        #expect(proyek.rasioAwal == nil)
        #expect(applied)
    }

    @Test("A project saved with ratios keeps using them after it is reopened")
    func resumeUsesSavedRatios() async {
        let proyek = makeProyek()
        proyek.visibleAverageAwal = 1000
        proyek.rasioAwal = [0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2]
        let (viewModel, liveReadings) = await makeLive(proyek: proyek, initial: reading())

        liveReadings.yield(reading(channel7: 400, average: 990))
        let expected = expectedConcentration(of: Self.lighterRatios, baseline: Self.baselineRatios)
        let applied = await waitUntil { abs((viewModel.latestConcentration ?? 100) - expected) < 0.0001 }

        #expect(applied)
    }

    @Test("Measuring the initial color again clears the saved ratios")
    func resetClearsRatios() async {
        let proyek = makeProyek()
        let (viewModel, _) = await makeLive(proyek: proyek, initial: reading())
        viewModel.tetapkanWarnaAwal(in: RecordingModelPersistence())

        #expect(viewModel.ukurUlangWarnaAwal(in: RecordingModelPersistence()))

        #expect(proyek.rasioAwal == nil)
    }
}
