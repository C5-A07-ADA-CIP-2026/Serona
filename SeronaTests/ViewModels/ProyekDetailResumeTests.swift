//
//  ProyekDetailResumeTests.swift
//  SeronaTests
//

import Foundation
@testable import Serona
import Testing

/// A project whose scan was started keeps its stage when the detail screen is opened again.
@MainActor
struct ProyekDetailResumeTests {
    private func makeProyek() -> Proyek {
        Proyek(nama: "Seragam RT 5", perangkatNama: "ESP 32", resep: .sample(), jumlahKain: 3)
    }

    private func makeViewModel(
        proyek: Proyek? = nil,
        service: StubDeviceConnectionService = StubDeviceConnectionService()
    ) -> ProyekDetailViewModel {
        ProyekDetailViewModel(proyek: proyek ?? makeProyek(), service: service)
    }

    @Test("Scanning saves nothing: the initial color and pH are left for the user to set")
    func scanSavesNothing() async {
        let proyek = makeProyek()
        let persistence = RecordingModelPersistence()
        let viewModel = makeViewModel(proyek: proyek, service: StubDeviceConnectionService(
            initial: ColorMeasurement(visibleAverage: 1000, clear: 1200, nir: 200, waterPH: 11)
        ))

        await viewModel.mulaiPindai()

        #expect(viewModel.isDataScanned)
        #expect(proyek.visibleAverageAwal == nil)
        #expect(proyek.phAwal == nil)
        #expect(persistence.events.isEmpty)
    }

    @Test("Setting the initial color saves the baseline on the project")
    func setColorSavesBaseline() async {
        let proyek = makeProyek()
        let persistence = RecordingModelPersistence()
        let viewModel = makeViewModel(proyek: proyek, service: StubDeviceConnectionService(
            initial: ColorMeasurement(visibleAverage: 1000, clear: 1200, nir: 200, waterPH: 11)
        ))

        await viewModel.pindaiDenganWarnaAwal(in: persistence)

        #expect(proyek.visibleAverageAwal == 1000)
        #expect(persistence.events == [.save])
    }

    @Test("Reopening a scanned project resumes at the scanned stage without reading the device again")
    func reopenRestoresScannedStage() async {
        let proyek = makeProyek()
        let first = makeViewModel(proyek: proyek, service: StubDeviceConnectionService(
            initial: ColorMeasurement(visibleAverage: 1000, clear: 1200, nir: 200, waterPH: 11),
            updates: [ColorMeasurement(visibleAverage: 1000, clear: 1200, nir: 200, waterPH: 11)]
        ))
        await first.pindaiDenganWarnaAwal(in: RecordingModelPersistence())
        _ = await waitUntil { first.latestWaterPH == 11 }
        first.tetapkanPHAwal(in: RecordingModelPersistence())
        first.berhenti()

        let service = StubDeviceConnectionService()
        let reopened = makeViewModel(proyek: proyek, service: service)

        #expect(reopened.isDataScanned)
        #expect(reopened.isInitialPHSet)
        #expect(reopened.measurements.initial[2].value == "11")
        #expect(service.readCounter.value == 0)
    }

    @Test("A reopened project streams current values relative to the saved baseline")
    func reopenResumesStreaming() async {
        let proyek = makeProyek()
        await makeViewModel(proyek: proyek).pindaiDenganWarnaAwal(in: RecordingModelPersistence())
        let reopened = makeViewModel(proyek: proyek, service: StubDeviceConnectionService(
            updates: [ColorMeasurement(visibleAverage: 735, clear: 1200, nir: 200, waterPH: 10.5)]
        ))

        reopened.lanjutkanPengukuran()
        let didUpdate = await waitUntil { reopened.measurements.current.first?.value == "73.5%" }

        #expect(didUpdate)
        #expect(reopened.latestConcentration == 73.5)
    }

    @Test("A reopened project can still be finished")
    func reopenedProjectCanFinish() async {
        let proyek = makeProyek()
        await makeViewModel(proyek: proyek).pindaiDenganWarnaAwal(in: RecordingModelPersistence())
        let reopened = makeViewModel(proyek: proyek)

        #expect(reopened.selesaikan(in: RecordingModelPersistence()))
        #expect(proyek.status == .nonaktif)
    }

    @Test("A project that was never scanned stays unscanned when reopened and does not stream")
    func unscannedProjectStaysUnscanned() {
        let viewModel = makeViewModel()

        viewModel.lanjutkanPengukuran()

        #expect(!viewModel.isDataScanned)
    }
}
