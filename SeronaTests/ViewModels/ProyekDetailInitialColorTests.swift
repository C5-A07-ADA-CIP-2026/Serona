//
//  ProyekDetailInitialColorTests.swift
//  SeronaTests
//

import Foundation
@testable import Serona
import Testing

/// The initial color (100%) is the live reading the user chooses, not whatever the sensor read first.
@MainActor
struct ProyekDetailInitialColorTests {
    private func makeProyek() -> Proyek {
        Proyek(nama: "Seragam RT 5", perangkatNama: "ESP 32", resep: .sample(batasKepekatan: 80), jumlahKain: 3)
    }

    private func reading(_ visibleAverage: Double) -> ColorMeasurement {
        ColorMeasurement(visibleAverage: visibleAverage, clear: 1200, nir: 200, waterPH: 11)
    }

    /// A scanned view model whose live stream the test controls.
    private func makeLive(
        proyek: Proyek? = nil
    ) async -> (ProyekDetailViewModel, AsyncStream<ColorMeasurement>.Continuation) {
        let (updates, liveReadings) = AsyncStream<ColorMeasurement>.makeStream()
        let viewModel = ProyekDetailViewModel(
            proyek: proyek ?? makeProyek(),
            service: StubDeviceConnectionService(initial: reading(1000), liveUpdates: updates)
        )
        await viewModel.mulaiPindai()
        return (viewModel, liveReadings)
    }

    @Test("Before it is set the concentration is unknown, however the sensor reads")
    func concentrationUnknownUntilSet() async {
        let (viewModel, liveReadings) = await makeLive()

        liveReadings.yield(reading(900))
        let didConsume = await waitUntil { viewModel.latestWaterPH == 11 }

        #expect(didConsume)
        #expect(!viewModel.isInitialColorSet)
        #expect(viewModel.latestConcentration == nil)
        #expect(viewModel.measurements.initial[0].value == "—")
        #expect(viewModel.measurements.current[0].value == "—")
    }

    @Test("Setting is not possible before the project is scanned")
    func cannotSetBeforeScan() {
        let viewModel = ProyekDetailViewModel(proyek: makeProyek(), service: StubDeviceConnectionService())

        #expect(!viewModel.canSetInitialColor)
        #expect(!viewModel.tetapkanWarnaAwal(in: RecordingModelPersistence()))
    }

    @Test("The latest live reading becomes the 100% baseline, saved and shown")
    func setsInitialColor() async {
        let proyek = makeProyek()
        let persistence = RecordingModelPersistence()
        let (viewModel, liveReadings) = await makeLive(proyek: proyek)
        liveReadings.yield(reading(800))
        _ = await waitUntil { viewModel.canSetInitialColor && viewModel.latestWaterPH == 11 }

        #expect(viewModel.tetapkanWarnaAwal(in: persistence))

        #expect(proyek.visibleAverageAwal == 800)
        #expect(viewModel.isInitialColorSet)
        #expect(!viewModel.canSetInitialColor)
        #expect(viewModel.latestConcentration == 100)
        #expect(viewModel.measurements.initial[0].value == "100%")
        #expect(viewModel.measurements.current[0].value == "100.0%")
        #expect(persistence.events == [.save])
    }

    @Test("Readings after setting are compared with the baseline")
    func laterReadingsUseBaseline() async {
        let (viewModel, liveReadings) = await makeLive()
        viewModel.tetapkanWarnaAwal(in: RecordingModelPersistence())

        liveReadings.yield(reading(750))
        let didUpdate = await waitUntil { viewModel.latestConcentration == 75 }

        #expect(didUpdate)
        #expect(viewModel.measurements.current[0].value == "75.0%")
        #expect(viewModel.isConcentrationLow)
    }

    @Test("A failed save keeps the initial color unset and reports the error")
    func setSaveFailureIsRolledBack() async {
        let proyek = makeProyek()
        let persistence = RecordingModelPersistence()
        persistence.saveError = StubSaveError()
        let (viewModel, _) = await makeLive(proyek: proyek)

        #expect(!viewModel.tetapkanWarnaAwal(in: persistence))

        #expect(proyek.visibleAverageAwal == nil)
        #expect(!viewModel.isInitialColorSet)
        #expect(viewModel.measurements.initial[0].value == "—")
        #expect(viewModel.saveError == "Gagal menyimpan proyek: disk penuh")
    }

    @Test("Measuring again clears the baseline and the concentration so a new one can be set")
    func resetsInitialColor() async {
        let proyek = makeProyek()
        let persistence = RecordingModelPersistence()
        let (viewModel, _) = await makeLive(proyek: proyek)
        viewModel.tetapkanWarnaAwal(in: RecordingModelPersistence())

        #expect(viewModel.ukurUlangWarnaAwal(in: persistence))

        #expect(proyek.visibleAverageAwal == nil)
        #expect(!viewModel.isInitialColorSet)
        #expect(viewModel.canSetInitialColor)
        #expect(viewModel.latestConcentration == nil)
        #expect(viewModel.measurements.initial[0].value == "—")
        #expect(viewModel.measurements.current[0].value == "—")
        #expect(persistence.events == [.save])
    }

    @Test("A failed save while measuring again keeps the previous baseline")
    func resetSaveFailureIsRolledBack() async {
        let proyek = makeProyek()
        let persistence = RecordingModelPersistence()
        let (viewModel, _) = await makeLive(proyek: proyek)
        viewModel.tetapkanWarnaAwal(in: RecordingModelPersistence())
        persistence.saveError = StubSaveError()

        #expect(!viewModel.ukurUlangWarnaAwal(in: persistence))

        #expect(proyek.visibleAverageAwal == 1000)
        #expect(viewModel.isInitialColorSet)
        #expect(viewModel.saveError == "Gagal menyimpan proyek: disk penuh")
    }

    @Test("A finished project cannot change its initial color")
    func finishedProjectIsLocked() async {
        let (viewModel, _) = await makeLive()
        viewModel.selesaikan(in: RecordingModelPersistence())

        #expect(!viewModel.canSetInitialColor)
        #expect(!viewModel.tetapkanWarnaAwal(in: RecordingModelPersistence()))
    }

    @Test("A pH set before the color baseline is still shown after scanning again")
    func phSurvivesRescan() async {
        let proyek = makeProyek()
        proyek.phAwal = 10
        let (viewModel, _) = await makeLive(proyek: proyek)

        #expect(viewModel.isInitialPHSet)
        #expect(viewModel.measurements.initial[2].value == "10")
    }
}
