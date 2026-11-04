//
//  ProyekDetailInitialPHTests.swift
//  SeronaTests
//

import Foundation
@testable import Serona
import Testing

/// The initial pH is what the user chooses from the live sensor reading, not whatever the sensor read first.
@MainActor
struct ProyekDetailInitialPHTests {
    private func makeProyek() -> Proyek {
        Proyek(nama: "Seragam RT 5", perangkatNama: "ESP 32", resep: .sample(), jumlahKain: 3)
    }

    private func reading(_ waterPH: Double?) -> ColorMeasurement {
        ColorMeasurement(visibleAverage: 1000, clear: 1200, nir: 200, waterPH: waterPH)
    }

    /// A scanned view model that has already received `waterPH` from the live stream.
    private func makeScanned(
        proyek: Proyek? = nil,
        waterPH: Double? = 11
    ) async -> ProyekDetailViewModel {
        let viewModel = ProyekDetailViewModel(
            proyek: proyek ?? makeProyek(),
            service: StubDeviceConnectionService(initial: reading(nil), updates: [reading(waterPH)])
        )
        await viewModel.mulaiPindai()
        if waterPH != nil {
            _ = await waitUntil { viewModel.latestWaterPH == waterPH }
        } else {
            _ = await waitUntil { viewModel.latestConcentration != nil }
        }
        return viewModel
    }

    @Test("Setting is not possible before a pH reading arrives")
    func cannotSetWithoutReading() async {
        let viewModel = await makeScanned(waterPH: nil)

        #expect(!viewModel.canSetInitialPH)
        #expect(!viewModel.tetapkanPHAwal(in: RecordingModelPersistence()))
        #expect(viewModel.proyek.phAwal == nil)
    }

    @Test("Setting is not possible before the project is scanned")
    func cannotSetBeforeScan() {
        let viewModel = ProyekDetailViewModel(proyek: makeProyek(), service: StubDeviceConnectionService())

        #expect(!viewModel.canSetInitialPH)
    }

    @Test("A live reading can be set as the initial pH, saved and shown")
    func setsInitialPH() async {
        let proyek = makeProyek()
        let persistence = RecordingModelPersistence()
        let viewModel = await makeScanned(proyek: proyek, waterPH: 10.5)

        #expect(viewModel.canSetInitialPH)
        #expect(viewModel.tetapkanPHAwal(in: persistence))

        #expect(proyek.phAwal == 10.5)
        #expect(viewModel.isInitialPHSet)
        #expect(!viewModel.canSetInitialPH)
        #expect(viewModel.measurements.initial[2].value == "10.5")
        #expect(persistence.events == [.save])
    }

    @Test("The initial pH stays fixed while the live reading keeps changing")
    func initialPHIgnoresLaterReadings() async {
        let (readings, liveReadings) = AsyncStream.makeStream(of: ColorMeasurement.self)
        let proyek = makeProyek()
        let viewModel = ProyekDetailViewModel(
            proyek: proyek,
            service: StubDeviceConnectionService(initial: reading(nil), liveUpdates: readings)
        )
        await viewModel.mulaiPindai()
        liveReadings.yield(reading(11))
        _ = await waitUntil { viewModel.latestWaterPH == 11 }
        viewModel.tetapkanPHAwal(in: RecordingModelPersistence())

        liveReadings.yield(reading(9))
        let didUpdate = await waitUntil { viewModel.latestWaterPH == 9 }
        liveReadings.finish()

        #expect(didUpdate)
        #expect(proyek.phAwal == 11)
        #expect(viewModel.measurements.initial[2].value == "11")
        #expect(viewModel.measurements.current[1].value == "9")
    }

    @Test("A failed save keeps the initial pH unset and reports the error")
    func setSaveFailureIsRolledBack() async {
        let proyek = makeProyek()
        let persistence = RecordingModelPersistence()
        persistence.saveError = StubSaveError()
        let viewModel = await makeScanned(proyek: proyek)

        #expect(!viewModel.tetapkanPHAwal(in: persistence))

        #expect(proyek.phAwal == nil)
        #expect(!viewModel.isInitialPHSet)
        #expect(viewModel.measurements.initial[2].value == "—")
        #expect(viewModel.saveError == "Gagal menyimpan proyek: disk penuh")
    }

    @Test("Measuring again clears the initial pH so a new one can be set")
    func resetsInitialPH() async {
        let proyek = makeProyek()
        let persistence = RecordingModelPersistence()
        let viewModel = await makeScanned(proyek: proyek)
        viewModel.tetapkanPHAwal(in: RecordingModelPersistence())

        #expect(viewModel.ukurUlangPHAwal(in: persistence))

        #expect(proyek.phAwal == nil)
        #expect(!viewModel.isInitialPHSet)
        #expect(viewModel.canSetInitialPH)
        #expect(viewModel.measurements.initial[2].value == "—")
        #expect(persistence.events == [.save])
    }

    @Test("A failed save while measuring again keeps the previous initial pH")
    func resetSaveFailureIsRolledBack() async {
        let proyek = makeProyek()
        let persistence = RecordingModelPersistence()
        let viewModel = await makeScanned(proyek: proyek, waterPH: 11)
        viewModel.tetapkanPHAwal(in: RecordingModelPersistence())
        persistence.saveError = StubSaveError()

        #expect(!viewModel.ukurUlangPHAwal(in: persistence))

        #expect(proyek.phAwal == 11)
        #expect(viewModel.isInitialPHSet)
        #expect(viewModel.saveError == "Gagal menyimpan proyek: disk penuh")
    }

    @Test("A finished project cannot change its initial pH")
    func finishedProjectIsLocked() async {
        let proyek = makeProyek()
        let viewModel = await makeScanned(proyek: proyek)
        viewModel.selesaikan(in: RecordingModelPersistence())

        #expect(!viewModel.canSetInitialPH)
        #expect(!viewModel.tetapkanPHAwal(in: RecordingModelPersistence()))
    }
}
