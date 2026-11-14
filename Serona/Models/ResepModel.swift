//
//  ResepModel.swift
//  Serona
//
//  Created by Dina on 21/10/26.
//

import Foundation
import SwiftData

@Model
class Resep {
    var namaWarna: String
    var warnaHex: String?
    var air: Int
    var kepekatan: Double
    var batasPH: Double
    var pewarna: [Bahan]
    var zatPembantu: [Bahan]
    var dibuat: Date
    @Relationship(deleteRule: .nullify, inverse: \Proyek.resep) var proyekTersimpan: [Proyek] = []

    // swiftlint:disable opening_brace
    init(namaWarna: String, warnaHex: String? = nil,
         air: Int, kepekatan: Double, batasPH: Double,
         pewarna: [Bahan] = [], zatPembantu: [Bahan] = [], dibuat: Date = .now)
    {
        self.namaWarna = namaWarna
        self.warnaHex = warnaHex
        self.air = air
        self.kepekatan = kepekatan
        self.batasPH = batasPH
        self.pewarna = pewarna
        self.zatPembantu = zatPembantu
        self.dibuat = dibuat
    }
    // swiftlint:enable opening_brace
}

extension [Resep] {
    /// Resep yang `namaWarna` memuat `teks`, tanpa peduli huruf besar/kecil.
    /// Teks kosong atau hanya spasi mengembalikan semua resep.
    func cari(_ teks: String) -> [Resep] {
        let kataKunci = teks.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !kataKunci.isEmpty else { return self }
        return filter {
            $0.namaWarna.localizedCaseInsensitiveContains(kataKunci)
        }
    }
}

struct Bahan: Codable, Hashable {
    var kode: String
    var gram: Double
}

struct BahanInput: Identifiable {
    let id = UUID()
    var kode = ""
    var gram: Double?

    var bahan: Bahan {
        Bahan(
            kode: kode.trimmingCharacters(in: .whitespaces),
            gram: gram ?? 0
        )
    }
}

extension BahanInput {
    var terisi: Bool {
        kode.tidakKosong && (gram ?? 0) > 0
    }
}

extension BahanInput {
    /// Baris yang belum disentuh: tanpa kode dan tanpa gram.
    var kosong: Bool {
        !kode.tidakKosong && (gram ?? 0) == 0
    }
}

extension [BahanInput] {
    var semuaTerisi: Bool {
        allSatisfy(\.terisi)
    }

    /// Baris yang terisi lengkap; baris kosong dibuang.
    var barisTerisi: [BahanInput] {
        filter(\.terisi)
    }

    /// Minimal satu baris terisi, dan tidak ada baris yang setengah terisi.
    /// Baris kosong diabaikan.
    var valid: Bool {
        !barisTerisi.isEmpty && allSatisfy { $0.terisi || $0.kosong }
    }
}
