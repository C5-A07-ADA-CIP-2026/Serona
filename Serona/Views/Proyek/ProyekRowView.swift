//
//  ProyekRowView.swift
//  Serona
//

import SwiftUI

struct ProyekRowView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .headline) private var ukuranSwatch = 44.0

    let proyek: Proyek

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 12))
        layout {
            WarnaKotak(hex: proyek.warnaHex, cornerRadius: 8, iconSize: 18)
                .frame(width: min(ukuranSwatch, 64), height: min(ukuranSwatch, 64))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(proyek.nama)
                    .font(.headline)
                Text(proyek.tanggal, format: .dateTime.day().month(.abbreviated).year().hour().minute())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ProyekRowView(proyek: .previewSample)
        .padding()
}

#Preview("Accessibility 5") {
    ProyekRowView(proyek: .previewSample)
        .padding()
        .dynamicTypeSize(.accessibility5)
}

extension Proyek {
    /// A project for previews. It is not inserted into any context.
    static var previewSample: Proyek {
        Proyek(
            nama: "Seragam RT 5",
            perangkatNama: "ESP 32",
            resep: Resep(
                namaWarna: "Merah Marun", warnaHex: "#B50202",
                air: 1000, kepekatan: 80, batasPH: 7,
                pewarna: [Bahan(kode: "Naphtol AS", gram: 5)],
                zatPembantu: [Bahan(kode: "Kostik", gram: 2)]
            ),
            jumlahKain: 2
        )
    }
}
