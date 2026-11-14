//
//  ProyekFormSections.swift
//  Serona
//

import SwiftUI

/// Label on the left, value on the right; stacked at accessibility sizes so long text does not wrap mid-word.
struct BarisInfo: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let judul: String
    let nilai: String
    var tebal = false
    var peringatan = false

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout())
        layout {
            Text(judul)

            if !dynamicTypeSize.isAccessibilitySize {
                Spacer()
            }

            Text(nilai)
                .monospacedDigit()
        }
        .fontWeight(tebal ? .semibold : .regular)
        .foregroundStyle(peringatan ? Color.peringatan : Color.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Heading used by every section of the project forms.
struct JudulBagian: View {
    let teks: String

    var body: some View {
        Text(teks)
            .font(.title3.weight(.semibold))
            .accessibilityAddTraits(.isHeader)
    }
}

/// "Perangkat   ESP 32"
struct PerangkatBaris: View {
    let nama: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            BarisInfo(judul: "Perangkat", nilai: nama, tebal: true)
            Divider()
        }
    }
}

/// The color of a recipe as a swatch with its name, and an optional button to remove it.
struct WarnaSwatchView: View {
    let namaWarna: String
    let warnaHex: String?
    var onHapus: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(namaWarna)
                .font(.headline)

            WarnaKotak(hex: warnaHex, cornerRadius: 10, iconSize: 28)
                .frame(maxWidth: .infinity)
                .frame(height: 80)
                .overlay(alignment: .topTrailing) {
                    if let onHapus {
                        Button(action: onHapus) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, .black.opacity(0.6))
                                .padding(8)
                        }
                        .accessibilityLabel("Hapus warna")
                    }
                }
                .accessibilityHidden(onHapus == nil)
        }
    }
}

/// "Resep Warna": the dye and auxiliary ingredients of the chosen recipe.
struct ResepWarnaView: View {
    let pewarna: [Bahan]
    let zatPembantu: [Bahan]
    var air: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            JudulBagian(teks: "Resep Warna")

            if pewarna.isEmpty, zatPembantu.isEmpty {
                Text("Resep ini belum memiliki bahan.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(Array(pewarna.enumerated()), id: \.offset) { _, bahan in
                BarisInfo(judul: bahan.kode, nilai: bahan.gramTeks)
            }

            if let air {
                BarisInfo(judul: "Air", nilai: "\(air) ml")
            }

            ForEach(Array(zatPembantu.enumerated()), id: \.offset) { _, bahan in
                BarisInfo(judul: bahan.kode, nilai: bahan.gramTeks)
            }
        }
    }
}

struct JumlahKainBaris: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @Binding var jumlahKain: Int
    var minimum = 0

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout())
        layout {
            JudulBagian(teks: "Jumlah Kain")

            if !dynamicTypeSize.isAccessibilitySize {
                Spacer()
            }

            Stepper(value: $jumlahKain, in: minimum ... Int.max, step: 1) {
                Text("\(jumlahKain)")
                    .monospacedDigit()
                    .accessibilityLabel("Jumlah kain")
            }
            .accessibilityValue("\(jumlahKain)")
        }
    }
}

extension Bahan {
    /// Locale-independent, drops trailing zeros: 5 -> "5 g", 2.5 -> "2.5 g".
    var gramTeks: String {
        "\(String(format: "%g", gram)) g"
    }
}

#Preview("Resep Warna") {
    VStack(alignment: .leading, spacing: 24) {
        WarnaSwatchView(namaWarna: "Merah Marun", warnaHex: "#B50202", onHapus: {})
        ResepWarnaView(
            pewarna: [Bahan(kode: "Naphtol AS", gram: 5)],
            zatPembantu: [Bahan(kode: "Kostik", gram: 2.5)]
        )
        JumlahKainBaris(jumlahKain: .constant(2))
    }
    .padding(24)
}

#Preview("Resep Warna accessibility size") {
    ScrollView {
        VStack(alignment: .leading, spacing: 24) {
            WarnaSwatchView(namaWarna: "Merah Marun", warnaHex: "#B50202", onHapus: {})
            ResepWarnaView(
                pewarna: [Bahan(kode: "Naphtol AS", gram: 5)],
                zatPembantu: [Bahan(kode: "Kostik", gram: 2.5)]
            )
            JumlahKainBaris(jumlahKain: .constant(2))
        }
        .padding(24)
    }
    .dynamicTypeSize(.accessibility5)
}
