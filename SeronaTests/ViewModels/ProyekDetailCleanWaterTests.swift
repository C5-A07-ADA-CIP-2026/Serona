//
//  ProyekDetailCleanWaterTests.swift
//  SeronaTests
//

import Foundation
@testable import Serona
import Testing

/// Once the clean-water reading is set as well, the concentration is absorbance against the baseline.
@MainActor
struct ProyekDetailCleanWaterTests {
    private let cleanRatios = [Double](repeating: 0.4, count: 8)

    private func makeProyek() -> Proyek {
        let resep = Resep(
            namaWarna: "Ungu", warnaHex: "#4B0082", air: 1000, kepekatan: 80, batasPH: 7,
            pewarna: [Bahan(kode: "Merah", gram: 10)]
        )
        return Proyek(nama: "Seragam RT 5", perangkatNama: "ESP 32", resep: resep, jumlahKain: 3)
    }

    private func reading(ratio: Double) -> ColorMeasurement {
        let count = UInt16((ratio * 1000).rounded())
        return ColorMeasurement(
            visibleAverage: 1000, clear: 1000, nir: 10, waterPH: 11,
            channels: [UInt16](repeating: count, count: 8), clearFirst: 1000
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

    @Test("The latest reading's ratios are saved as the clean water")
    func setsCleanWater() async {
        let proyek = makeProyek()
        let (viewModel, _) = await makeLive(proyek: proyek, initial: reading(ratio: 0.4))
        let persistence = RecordingModelPersistence()

        #expect(viewModel.canSetCleanWater)
        #expect(viewModel.tetapkanAirBersih(in: persistence))

        #expect(proyek.rasioAirBersih == cleanRatios)
        #expect(viewModel.isCleanWaterSet)
        #expect(persistence.events == [.save])
    }

    @Test("A failed save keeps the clean water unset and reports the error")
    func setSaveFailureIsRolledBack() async {
        let proyek = makeProyek()
        let (viewModel, _) = await makeLive(proyek: proyek, initial: reading(ratio: 0.4))
        let persistence = RecordingModelPersistence()
        persistence.saveError = StubSaveError()

        #expect(!viewModel.tetapkanAirBersih(in: persistence))

        #expect(proyek.rasioAirBersih == nil)
        #expect(viewModel.saveError != nil)
    }

    @Test("It cannot be set before scanning, without channels, or twice")
    func guards() async {
        let unscanned = ProyekDetailViewModel(
            proyek: makeProyek(),
            service: StubDeviceConnectionService(initial: reading(ratio: 0.4))
        )
        #expect(!unscanned.tetapkanAirBersih(in: RecordingModelPersistence()))

        let noChannels = ColorMeasurement(visibleAverage: 1000, clear: 1000, nir: 10)
        let (withoutChannels, _) = await makeLive(initial: noChannels)
        #expect(!withoutChannels.canSetCleanWater)

        let (viewModel, _) = await makeLive(initial: reading(ratio: 0.4))
        #expect(viewModel.tetapkanAirBersih(in: RecordingModelPersistence()))
        #expect(!viewModel.tetapkanAirBersih(in: RecordingModelPersistence()))
    }

    @Test("With clean water and baseline set, less dye reads lower and the dye to add follows")
    func concentrationFromAbsorbance() async {
        let (viewModel, liveReadings) = await makeLive(initial: reading(ratio: 0.4))
        viewModel.tetapkanAirBersih(in: RecordingModelPersistence())
        // The bath with dye: T = 0.5.
        liveReadings.yield(reading(ratio: 0.2))
        _ = await waitUntil { viewModel.latestConcentration != nil }
        viewModel.tetapkanWarnaAwal(in: RecordingModelPersistence())

        liveReadings.yield(reading(ratio: 0.3)) // T = 0.75
        let expected = log10(1 / 0.75) / log10(1 / 0.5) * 100
        let applied = await waitUntil { abs((viewModel.latestConcentration ?? 100) - expected) < 1e-6 }

        #expect(applied)
        let tambahan = viewModel.penambahanPewarna
        #expect(tambahan?.first?.kode == "Merah")
        #expect(abs((tambahan?.first?.gram ?? 0) - 30 * (1 - expected / 100)) < 1e-6)
    }

    @Test("Without clean water the concentration keeps the older formula and no dye amount is offered")
    func noCleanWaterKeepsFallback() async {
        let (viewModel, liveReadings) = await makeLive(initial: reading(ratio: 0.2))
        viewModel.tetapkanWarnaAwal(in: RecordingModelPersistence())

        liveReadings.yield(reading(ratio: 0.1))
        let applied = await waitUntil { abs((viewModel.latestConcentration ?? 100) - 50) < 1e-6 }

        #expect(applied)
        #expect(viewModel.penambahanPewarna == nil)
    }

    @Test("Measuring the clean water again clears it")
    func resetsCleanWater() async {
        let proyek = makeProyek()
        let (viewModel, _) = await makeLive(proyek: proyek, initial: reading(ratio: 0.4))
        viewModel.tetapkanAirBersih(in: RecordingModelPersistence())

        #expect(viewModel.ukurUlangAirBersih(in: RecordingModelPersistence()))

        #expect(proyek.rasioAirBersih == nil)
        #expect(!viewModel.isCleanWaterSet)
    }

    @Test("A project saved with clean water keeps using it after it is reopened")
    func resumeUsesSavedCleanWater() async {
        let proyek = makeProyek()
        proyek.visibleAverageAwal = 1000
        proyek.rasioAwal = [Double](repeating: 0.2, count: 8)
        proyek.rasioAirBersih = cleanRatios
        let (viewModel, liveReadings) = await makeLive(proyek: proyek, initial: reading(ratio: 0.2))

        liveReadings.yield(reading(ratio: 0.3))
        let expected = log10(1 / 0.75) / log10(1 / 0.5) * 100
        let applied = await waitUntil { abs((viewModel.latestConcentration ?? 100) - expected) < 1e-6 }

        #expect(applied)
        #expect(viewModel.isCleanWaterSet)
    }
}
