//
//  ProyekDetailChannelConcentrationTests.swift
//  SeronaTests
//

import Foundation
@testable import Serona
import Testing

/// The app, not the device, computes the concentration: the lowest per-channel transmittance (channel / clear)
/// against the ratios saved when the initial color was set.
@MainActor
struct ProyekDetailChannelConcentrationTests {
    private func makeProyek() -> Proyek {
        Proyek(nama: "Seragam RT 5", perangkatNama: "ESP 32", resep: .sample(batasKepekatan: 80), jumlahKain: 3)
    }

    /// All channels at 200 against a clear of 1000, except F5 (`channel5`, default 200).
    private func reading(channel5: UInt16 = 200, average: Double = 1000, channels: Bool = true) -> ColorMeasurement {
        ColorMeasurement(
            visibleAverage: average,
            clear: 1000,
            nir: 10,
            waterPH: 11,
            channels: channels ? [200, 200, 200, 200, channel5, 200, 200, 200] : nil,
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

    @Test("Afterwards the concentration follows the most absorbed channel, not the visible average")
    func concentrationUsesChannels() async {
        let (viewModel, liveReadings) = await makeLive(initial: reading())
        viewModel.tetapkanWarnaAwal(in: RecordingModelPersistence())

        // The visible average barely moves (990 of 1000) while F5 falls to 72% of its baseline.
        liveReadings.yield(reading(channel5: 144, average: 990))
        let applied = await waitUntil { viewModel.latestConcentration != 100 }

        #expect(applied)
        #expect(abs((viewModel.latestConcentration ?? 0) - 72) < 0.0001)
        #expect(viewModel.measurements.current[0].value == "72.0%")
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

        liveReadings.yield(reading(channel5: 144, average: 990))
        let applied = await waitUntil { viewModel.latestConcentration != nil }

        #expect(applied)
        #expect(abs((viewModel.latestConcentration ?? 0) - 72) < 0.0001)
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
