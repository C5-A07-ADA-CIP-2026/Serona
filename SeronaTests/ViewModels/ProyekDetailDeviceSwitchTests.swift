//
//  ProyekDetailDeviceSwitchTests.swift
//  SeronaTests
//

import Foundation
@testable import Serona
import Testing

@MainActor
struct ProyekDetailDeviceSwitchTests {
    private let seronaB = DiscoveredDevice(id: UUID(), nama: "Serona-A1B2C3D4")

    private func makeProyek() -> Proyek {
        Proyek(nama: "Seragam RT 5", perangkatNama: "ESP 32", resep: .sample(batasKepekatan: 80), jumlahKain: 3)
    }

    @Test("Switching device renames the device of the project and saves")
    func switchDeviceRenamesAndSaves() {
        let persistence = RecordingModelPersistence()
        let proyek = makeProyek()
        let viewModel = ProyekDetailViewModel(proyek: proyek, service: StubDeviceConnectionService())

        let didSwitch = viewModel.gantiPerangkat(seronaB, in: persistence)

        #expect(didSwitch)
        #expect(proyek.perangkatNama == "Serona-A1B2C3D4")
        #expect(persistence.events == [.save])
        #expect(viewModel.saveError == nil)
    }

    @Test("A failed save keeps the previous device name and reports the error")
    func switchDeviceFailureRollsBack() {
        let persistence = RecordingModelPersistence()
        persistence.saveError = StubSaveError()
        let proyek = makeProyek()
        let viewModel = ProyekDetailViewModel(proyek: proyek, service: StubDeviceConnectionService())

        let didSwitch = viewModel.gantiPerangkat(seronaB, in: persistence)

        #expect(!didSwitch)
        #expect(proyek.perangkatNama == "ESP 32")
        #expect(viewModel.saveError == "Gagal menyimpan proyek: disk penuh")
    }

    @Test("After a failed read, switching device renames the project and reads from the new device")
    func switchAfterFailedReadRetriesRead() async {
        let service = StubDeviceConnectionService(readError: StubSaveError())
        let proyek = makeProyek()
        let viewModel = ProyekDetailViewModel(proyek: proyek, service: service)
        await viewModel.mulaiPindai()
        #expect(viewModel.colorMeasurementError != nil)

        let didSwitch = await viewModel.pindahPerangkat(seronaB, in: RecordingModelPersistence())

        #expect(didSwitch)
        #expect(proyek.perangkatNama == "Serona-A1B2C3D4")
        #expect(service.readCounter.value == 2)
    }

    @Test("In the middle of a project the device can be switched and the bath data is kept")
    func switchMidProjectKeepsBathData() async {
        let service = StubDeviceConnectionService()
        let persistence = RecordingModelPersistence()
        let proyek = makeProyek()
        let viewModel = ProyekDetailViewModel(proyek: proyek, service: service)
        await viewModel.mulaiPindai()

        let didSwitch = await viewModel.pindahPerangkat(seronaB, in: persistence)

        #expect(didSwitch)
        #expect(proyek.perangkatNama == "Serona-A1B2C3D4")
        #expect(persistence.events.contains(.save))
        #expect(service.readCounter.value == 2)
    }

    @Test("A failed save does not retry the read")
    func switchSaveFailureDoesNotRetry() async {
        let service = StubDeviceConnectionService(readError: StubSaveError())
        let persistence = RecordingModelPersistence()
        persistence.saveError = StubSaveError()
        let viewModel = ProyekDetailViewModel(proyek: makeProyek(), service: service)
        await viewModel.mulaiPindai()

        let didSwitch = await viewModel.pindahPerangkat(seronaB, in: persistence)

        #expect(!didSwitch)
        #expect(service.readCounter.value == 1)
    }

    @Test("A finished project cannot be switched to another device")
    func switchDeviceIgnoredWhenFinished() {
        let persistence = RecordingModelPersistence()
        let proyek = makeProyek()
        proyek.selesaikan(kepekatanAkhir: 70, phAkhir: 7)
        let viewModel = ProyekDetailViewModel(proyek: proyek, service: StubDeviceConnectionService())

        let didSwitch = viewModel.gantiPerangkat(seronaB, in: persistence)

        #expect(!didSwitch)
        #expect(proyek.perangkatNama == "")
        #expect(persistence.events.isEmpty)
    }
}
