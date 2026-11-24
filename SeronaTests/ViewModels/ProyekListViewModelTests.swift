import Foundation
@testable import Serona
import SwiftData
import Testing

@MainActor
struct ProyekListViewModelTests {
    private func makeProyek(nama: String = "A", selesai: Bool) -> Proyek {
        let proyek = Proyek(nama: nama, perangkatNama: "ESP 32", resep: .sample(), jumlahKain: 2)
        if selesai {
            proyek.selesaikan(kepekatanAkhir: 90, phAkhir: 9)
        }
        return proyek
    }

    @Test("Asking to delete an inactive project waits for confirmation")
    func askToDeleteInactive() {
        let viewModel = ProyekListViewModel()
        let proyek = makeProyek(selesai: true)

        viewModel.mintaHapus(proyek)

        #expect(viewModel.proyekAkanDihapus === proyek)
    }

    @Test("An active project cannot be deleted")
    func activeProjectIsRefused() {
        let viewModel = ProyekListViewModel()

        viewModel.mintaHapus(makeProyek(selesai: false))

        #expect(viewModel.proyekAkanDihapus == nil)
    }

    @Test("Cancelling drops the pending deletion and deletes nothing")
    func cancelDeletion() {
        let viewModel = ProyekListViewModel()
        let persistence = RecordingModelPersistence()
        viewModel.mintaHapus(makeProyek(selesai: true))

        viewModel.batalHapus()

        #expect(viewModel.proyekAkanDihapus == nil)
        #expect(persistence.events.isEmpty)
    }

    @Test("Confirming deletes the project and saves")
    func confirmDeletes() {
        let viewModel = ProyekListViewModel()
        let persistence = RecordingModelPersistence()
        let proyek = makeProyek(selesai: true)
        viewModel.mintaHapus(proyek)

        let didDelete = viewModel.hapus(proyek, in: persistence)

        #expect(didDelete)
        #expect(persistence.events == [.delete, .save])
        #expect(isSameModel(persistence.deletedModels[0], proyek))
        #expect(viewModel.proyekAkanDihapus == nil)
        #expect(viewModel.deleteError == nil)
    }

    @Test("Confirming never deletes an active project")
    func confirmRefusesActive() {
        let viewModel = ProyekListViewModel()
        let persistence = RecordingModelPersistence()

        let didDelete = viewModel.hapus(makeProyek(selesai: false), in: persistence)

        #expect(!didDelete)
        #expect(persistence.events.isEmpty)
    }

    @Test("A failed save reports the error")
    func failedSaveReportsError() {
        let viewModel = ProyekListViewModel()
        let persistence = RecordingModelPersistence()
        persistence.saveError = StubSaveError()
        let proyek = makeProyek(selesai: true)
        viewModel.mintaHapus(proyek)

        let didDelete = viewModel.hapus(proyek, in: persistence)

        #expect(!didDelete)
        #expect(viewModel.deleteError == "Gagal menghapus proyek: disk penuh")
        #expect(viewModel.proyekAkanDihapus == nil)

        viewModel.clearDeleteError()
        #expect(viewModel.deleteError == nil)
    }

    @Test("Deleting removes the project from the store and keeps the rest")
    func deleteRemovesFromStore() throws {
        let context = try makeTestContext()
        let resep = Resep.sample()
        let dihapus = makeProyek(nama: "Dihapus", selesai: true)
        let tetap = makeProyek(nama: "Tetap", selesai: true)
        let aktif = makeProyek(nama: "Aktif", selesai: false)
        for proyek in [dihapus, tetap, aktif] {
            proyek.resep = resep
            context.insert(proyek)
        }
        try context.save()
        let viewModel = ProyekListViewModel()
        viewModel.mintaHapus(dihapus)

        let didDelete = viewModel.hapus(dihapus, in: context)

        #expect(didDelete)

        let freshContext = ModelContext(context.container)
        let names = try freshContext.fetch(FetchDescriptor<Proyek>()).map(\.nama).sorted()
        #expect(names == ["Aktif", "Tetap"])

        #expect(try freshContext.fetch(FetchDescriptor<Resep>()).count == 1)
    }

    @Test("An active project stays in the store when deleting is attempted")
    func activeProjectStaysInStore() throws {
        let context = try makeTestContext()
        let aktif = makeProyek(nama: "Aktif", selesai: false)
        context.insert(aktif)
        try context.save()

        let didDelete = ProyekListViewModel().hapus(aktif, in: context)

        #expect(!didDelete)
        #expect(try ModelContext(context.container).fetch(FetchDescriptor<Proyek>()).count == 1)
    }
}
