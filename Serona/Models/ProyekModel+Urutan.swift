//
//  ProyekModel+Urutan.swift
//  Serona
//

import Foundation

@MainActor
extension Sequence<Proyek> {
    /// Alphabetical by name, ignoring case and sorting numbers naturally ("Bak 2" before "Bak 10").
    /// Equal names keep the older project first.
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
