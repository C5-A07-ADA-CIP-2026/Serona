import Foundation
import Observation

@MainActor
@Observable
final class ProyekListViewModel {
    private(set) var proyekAkanDihapus: Proyek?
    private(set) var deleteError: String?

    func mintaHapus(_ proyek: Proyek) {
        guard proyek.status == .nonaktif else { return }
        proyekAkanDihapus = proyek
    }

    func batalHapus() {
        proyekAkanDihapus = nil
    }

    @discardableResult
    func hapus(_ proyek: Proyek, in persistence: some ModelPersisting) -> Bool {
        proyekAkanDihapus = nil
        guard proyek.status == .nonaktif else { return false }
        persistence.delete(proyek)
        do {
            try persistence.save()
            return true
        } catch {
            deleteError = "Gagal menghapus proyek: \(error.localizedDescription)"
            return false
        }
    }

    func clearDeleteError() {
        deleteError = nil
    }
}
