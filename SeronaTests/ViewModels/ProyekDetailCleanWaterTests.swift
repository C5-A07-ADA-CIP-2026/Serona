//
//  ProyekDetailCleanWaterTests.swift
//  SeronaTests
//

import Foundation
@testable import Serona
import Testing

/// The clean-water reading is fixed to `ProyekDetailViewModel.defaultCleanWaterRatios`, so the concentration is
/// always absorbance against the baseline and the user never sets or resets it.
@MainActor
struct ProyekDetailCleanWaterTests {
    private let cleanRatios = ProyekDetailViewModel.defaultCleanWaterRatios

    private func makeProyek() -> Proyek {
        let resep = Resep(
            namaWarna: "Ungu", warnaHex: "#4B0082", air: 1, kepekatan: 80, batasPH: 7,
            pewarna: [Bahan(kode: "Merah", gram: 10)]
        )
        return Proyek(nama: "Seragam RT 5", perangkatNama: "ESP 32", resep: resep)
    }

    private func reading(ratio: Double) -> ColorMeasurement {
        let count = UInt16((ratio * 1000).rounded())
        return ColorMeasurement(
            visibleAverage: 1000, clear: 1000, nir: 10, waterPH: 11,
            channels: [UInt16](repeating: count, count: 8), clearFirst: 1000
        )
    }

    /// Absorbance of a reading as a percentage of the baseline's, both against the fixed clean water.
    private func expectedConcentration(baseline: Double, current: Double) -> Double {
        let baselineRatios = [Double](repeating: baseline, count: 8)
        let currentRatios = [Double](repeating: current, count: 8)
        let initial = ColorMeasurement.absorbance(ratios: baselineRatios, cleanRatios: cleanRatios)
        let now = ColorMeasurement.absorbance(ratios: currentRatios, cleanRatios: cleanRatios)
        return (now ?? 0) / (initial ?? 1) * 100
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

    @Test("The clean water is always set, so the user is never asked to set it")
    func alwaysSet() async {
        let (viewModel, _) = await makeLive(initial: reading(ratio: 0.4))

        #expect(viewModel.isCleanWaterSet)
        #expect(!viewModel.canSetCleanWater)
    }

    @Test("Setting the clean water saves the fixed ratios, whatever the sensor reads")
    func setsFixedRatios() async {
        let proyek = makeProyek()
        let (viewModel, _) = await makeLive(proyek: proyek, initial: reading(ratio: 0.4))
        let persistence = RecordingModelPersistence()

        #expect(viewModel.tetapkanAirBersih(in: persistence))

        #expect(proyek.rasioAirBersih == cleanRatios)
        #expect(persistence.events == [.save])
    }

    @Test("A failed save reports the error")
    func saveFailureIsReported() async {
        let (viewModel, _) = await makeLive(initial: reading(ratio: 0.4))
        let persistence = RecordingModelPersistence()
        persistence.saveError = StubSaveError()

        #expect(!viewModel.tetapkanAirBersih(in: persistence))

        #expect(viewModel.saveError != nil)
    }

    @Test("Measuring the clean water again puts the fixed ratios back")
    func resetKeepsFixedRatios() async {
        let proyek = makeProyek()
        let (viewModel, _) = await makeLive(proyek: proyek, initial: reading(ratio: 0.4))

        #expect(viewModel.ukurUlangAirBersih(in: RecordingModelPersistence()))

        #expect(proyek.rasioAirBersih == cleanRatios)
        #expect(viewModel.isCleanWaterSet)
    }

    @Test("With the baseline set, less dye reads lower and the dye to add follows")
    func concentrationFromAbsorbance() async {
        let (viewModel, liveReadings) = await makeLive(initial: reading(ratio: 0.2))
        viewModel.tetapkanWarnaAwal(in: RecordingModelPersistence())

        liveReadings.yield(reading(ratio: 0.3))
        let expected = expectedConcentration(baseline: 0.2, current: 0.3)
        let applied = await waitUntil { abs((viewModel.latestConcentration ?? 100) - expected) < 1e-6 }

        #expect(applied)
        #expect(expected < 100)
        let tambahan = viewModel.penambahanPewarna
        #expect(tambahan?.first?.kode == "Merah")
        // C_target = 10 g of dye over 1 L; the bath is at the project's starting volume of 1 L.
        #expect(abs((tambahan?.first?.gram ?? 0) - 10 * (1 - expected / 100)) < 1e-6)
    }

    @Test("Without a baseline no dye amount is offered")
    func noBaselineNoDye() async {
        let (viewModel, _) = await makeLive(initial: reading(ratio: 0.2))

        #expect(viewModel.penambahanPewarna == nil)
    }

    @Test("A project reopened with its baseline keeps measuring against the fixed clean water")
    func resumeUsesFixedCleanWater() async {
        let proyek = makeProyek()
        proyek.visibleAverageAwal = 1000
        proyek.rasioAwal = [Double](repeating: 0.2, count: 8)
        let (viewModel, liveReadings) = await makeLive(proyek: proyek, initial: reading(ratio: 0.2))

        liveReadings.yield(reading(ratio: 0.3))
        let expected = expectedConcentration(baseline: 0.2, current: 0.3)
        let applied = await waitUntil { abs((viewModel.latestConcentration ?? 100) - expected) < 1e-6 }

        #expect(applied)
        #expect(viewModel.isCleanWaterSet)
    }
}
