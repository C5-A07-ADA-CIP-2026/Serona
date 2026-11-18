//
//  TambahProyekView+Previews.swift
//  Serona
//

import SwiftData
import SwiftUI

// MARK: - Previews

#Preview("Tambah Proyek Sheet", traits: .landscapeLeft) {
    BackgroundGradient()
        .sheet(isPresented: .constant(true)) {
            TambahProyekView(bakTitle: "Bak 1")
        }
        .modelContainer(for: SeronaSchema.models, inMemory: true)
}

#Preview("Tambah Proyek Terisi", traits: .landscapeLeft) {
    BackgroundGradient()
        .sheet(isPresented: .constant(true)) {
            TambahProyekView(bakTitle: "Bak 1", viewModel: .previewTerisi)
        }
        .modelContainer(for: SeronaSchema.models, inMemory: true)
}

#Preview("Tambah Proyek accessibility size", traits: .landscapeLeft) {
    BackgroundGradient()
        .sheet(isPresented: .constant(true)) {
            TambahProyekView(bakTitle: "Bak 1", viewModel: .previewTerisi)
                .dynamicTypeSize(.accessibility5)
        }
        .modelContainer(for: SeronaSchema.models, inMemory: true)
}

private extension TambahProyekViewModel {
    /// A form with a device, a color, a customer name and water already filled in.
    static var previewTerisi: TambahProyekViewModel {
        let viewModel = TambahProyekViewModel()
        viewModel.pilihPerangkat(DiscoveredDevice(id: UUID(), nama: "Serona Sensor"))
        viewModel.pilihResep(
            Resep(namaWarna: "Merah Marun", warnaHex: "#B50202", air: 10, kepekatan: 5, batasPH: 7)
        )
        viewModel.namaPemesan = "Ibu Sari"
        viewModel.jumlahAir = 10
        return viewModel
    }
}
