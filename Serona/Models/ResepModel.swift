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
    var kosong: Bool {
        !kode.tidakKosong && (gram ?? 0) == 0
    }
}

extension [BahanInput] {
    var semuaTerisi: Bool {
        allSatisfy(\.terisi)
    }

    var barisTerisi: [BahanInput] {
        filter(\.terisi)
    }

    var valid: Bool {
        !barisTerisi.isEmpty && allSatisfy { $0.terisi || $0.kosong } && tanpaKodeKembar
    }

    private var kodeDipakai: [String] {
        compactMap { $0.kode.tidakKosong ? $0.kode.kodeBaku : nil }
    }

    private var tanpaKodeKembar: Bool {
        Set(kodeDipakai).count == kodeDipakai.count
    }

    func pilihan(dari semua: [String], untukBaris id: BahanInput.ID) -> [String] {
        let dipakaiLain = Set(filter { $0.id != id && $0.kode.tidakKosong }.map(\.kode.kodeBaku))
        return semua.filter { !dipakaiLain.contains($0.kodeBaku) }
    }

    func masihAdaPilihan(dari semua: [String]) -> Bool {
        let dipakai = Set(kodeDipakai)
        return semua.contains { !dipakai.contains($0.kodeBaku) }
    }
}

private extension String {
    var kodeBaku: String {
        trimmingCharacters(in: .whitespaces).lowercased()
    }
}
