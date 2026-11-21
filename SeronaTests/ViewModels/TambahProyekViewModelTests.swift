//
//  TambahProyekViewModelTests.swift
//  SeronaTests
//

import Foundation
@testable import Serona
import Testing

@MainActor
struct TambahProyekViewModelTests {
    private let esp = DiscoveredDevice(id: UUID(), nama: "ESP 32")

    private func makeCompleteViewModel() -> TambahProyekViewModel {
        let viewModel = TambahProyekViewModel()
        viewModel.nama = "Seragam RT 5"
        viewModel.pilihPerangkat(esp)
        viewModel.pilihResep(.sample(namaWarna: "Merah Marun", warnaHex: "#B50202", batasKepekatan: 90, batasPH: 7.5))
        viewModel.jumlahKain = 2
        return viewModel
    }

    @Test("A new form is empty and cannot be submitted")
    func newFormCannotSubmit() {
        let viewModel = TambahProyekViewModel()

        #expect(viewModel.nama.isEmpty)
        #expect(viewModel.perangkat == nil)
        #expect(viewModel.resep == nil)
        #expect(viewModel.jumlahKain == 0)
        #expect(!viewModel.canSubmit)
    }

    @Test("A complete form can be submitted")
    func completeFormCanSubmit() {
        #expect(makeCompleteViewModel().canSubmit)
    }

    @Test("Removing the device blocks submitting")
    func hapusPerangkatBlocksSubmit() async {
        let service = StubDeviceConnectionService()
        let viewModel = TambahProyekViewModel(service: service)
        viewModel.nama = "Seragam RT 5"
        viewModel.pilihPerangkat(esp)
        viewModel.pilihResep(.sample(namaWarna: "Merah Marun", warnaHex: "#B50202", batasKepekatan: 90, batasPH: 7.5))
        viewModel.jumlahKain = 2

        await viewModel.hapusPerangkat()

        #expect(viewModel.perangkat == nil)
        #expect(!viewModel.canSubmit)
        #expect(service.disconnectCounter.value == 1)
    }

    @Test("Each missing field blocks submitting")
    func missingFieldBlocksSubmit() {
        let noName = makeCompleteViewModel()
        noName.nama = "   "
        #expect(!noName.canSubmit)

        let noDevice = TambahProyekViewModel()
        noDevice.nama = "A"
        noDevice.pilihResep(.sample())
        noDevice.jumlahKain = 1
        #expect(!noDevice.canSubmit)

        let noColor = makeCompleteViewModel()
        noColor.hapusResep()
        #expect(!noColor.canSubmit)

        let noFabric = makeCompleteViewModel()
        noFabric.jumlahKain = 0
        #expect(!noFabric.canSubmit)
    }

    @Test("Removing the chosen color clears it")
    func hapusResepClearsColor() {
        let viewModel = makeCompleteViewModel()

        viewModel.hapusResep()

        #expect(viewModel.resep == nil)
    }

    @Test("Saving inserts an active project that copies the form and the recipe")
    func saveInsertsActiveProject() throws {
        let persistence = RecordingModelPersistence()
        let viewModel = makeCompleteViewModel()
        viewModel.nama = "  Seragam RT 5  "

        let proyek = viewModel.simpan(in: persistence)

        #expect(persistence.events == [.insert, .save])
        let saved = try #require(proyek)
        #expect(isSameModel(persistence.insertedModels[0], saved))
        #expect(saved.nama == "Seragam RT 5")
        #expect(saved.perangkatNama == "ESP 32")
        #expect(saved.perangkatID == esp.id)
        #expect(saved.status == .aktif)
        #expect(saved.jumlahKain == 2)
        #expect(saved.namaWarna == "Merah Marun")
        #expect(saved.batasKepekatan == 90)
        #expect(saved.batasPH == 7.5)
        #expect(viewModel.saveError == nil)
    }

    @Test("An incomplete form saves nothing")
    func incompleteFormSavesNothing() {
        let persistence = RecordingModelPersistence()
        let viewModel = TambahProyekViewModel()
        viewModel.nama = "A"

        #expect(viewModel.simpan(in: persistence) == nil)
        #expect(persistence.events.isEmpty)
    }

    @Test("A failed save reports the error, keeps the form and removes the inserted project")
    func saveFailureKeepsForm() {
        let persistence = RecordingModelPersistence()
        persistence.saveError = StubSaveError()
        let viewModel = makeCompleteViewModel()

        let proyek = viewModel.simpan(in: persistence)

        #expect(proyek == nil)
        #expect(viewModel.saveError == "Gagal menyimpan proyek: disk penuh")
        #expect(persistence.events == [.insert, .save, .delete])
        #expect(viewModel.canSubmit)
    }

    @Test("After a failed save a retry can succeed")
    func saveRetryAfterFailure() {
        let persistence = RecordingModelPersistence()
        persistence.saveError = StubSaveError()
        let viewModel = makeCompleteViewModel()
        #expect(viewModel.simpan(in: persistence) == nil)

        persistence.saveError = nil
        viewModel.clearSaveError()

        #expect(viewModel.simpan(in: persistence) != nil)
        #expect(viewModel.saveError == nil)
    }

    @Test("Saving twice inserts one project")
    func saveTwiceInsertsOnce() {
        let persistence = RecordingModelPersistence()
        let viewModel = makeCompleteViewModel()
        #expect(viewModel.simpan(in: persistence) != nil)

        #expect(viewModel.simpan(in: persistence) == nil)

        #expect(persistence.events == [.insert, .save])
    }
}
