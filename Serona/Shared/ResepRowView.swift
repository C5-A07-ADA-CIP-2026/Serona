//
//  ResepRowView.swift
//  Serona
//

import SwiftUI

struct ResepRowView: View {
    let resep: Resep

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            WarnaKotak(hex: resep.warnaHex, cornerRadius: 12, iconSize: 44)
                .aspectRatio(1, contentMode: .fit)

            Text(resep.namaWarna)
                .font(.headline)
                .lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.20), radius: 10, x: 2, y: 2)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ResepRowView(
        resep: Resep(
            namaWarna: "Merah Marun",
            warnaHex: "#B50202",
            air: 1000,
            kepekatan: 80,
            batasPH: 7
        )
    )
    .padding()
}

#Preview("Accessibility 5") {
    ResepRowView(
        resep: Resep(
            namaWarna: "Merah Marun",
            warnaHex: "#B50202",
            air: 1000,
            kepekatan: 80,
            batasPH: 7
        )
    )
    .padding()
    .dynamicTypeSize(.accessibility5)
}
