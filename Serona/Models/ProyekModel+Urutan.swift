import Foundation

@MainActor
extension Sequence<Proyek> {
    func diurutkanAbjad() -> [Proyek] {
        sorted { kiri, kanan in
            switch kiri.nama.localizedStandardCompare(kanan.nama) {
            case .orderedAscending: true
            case .orderedDescending: false
            case .orderedSame: kiri.tanggal < kanan.tanggal
            }
        }
    }
}
