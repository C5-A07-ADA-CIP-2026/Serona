//
//  PenambahanSodaTests.swift
//  SeronaTests
//

import Foundation
@testable import Serona
import Testing

/// Soda from pH: C = 10^(pH - 14) x 40 g/L, the bath volume from C1 V = C2 (V + V_air),
/// and dm = max(0, (C_target - C2) x V2), split like the recipe's auxiliaries.
@Suite("Penambahan soda")
@MainActor
struct PenambahanSodaTests {
    /// Recipe water 1000 mL per cloth x 10 cloths = 10 L; auxiliaries 30 g per cloth, so C_target = 30 g/L.
    private static let zatBawaan = [Bahan(kode: "Soda Abu", gram: 20), Bahan(kode: "Soda Kostik", gram: 10)]

    private func makeProyek(zatPembantu: [Bahan] = zatBawaan, air: Int = 1000) -> Proyek {
        let resep = Resep(
            namaWarna: "Ungu", warnaHex: "#4B0082", air: air, kepekatan: 80, batasPH: 7,
            pewarna: [Bahan(kode: "Merah", gram: 5)], zatPembantu: zatPembantu
        )
        return Proyek(nama: "Seragam", perangkatNama: "ESP 32", resep: resep, jumlahKain: 10)
    }

    @Test("Soda concentration from pH is 10^(pH - 14) x 40 g/L")
    func sodaConcentration() {
        #expect(abs(PenambahanSoda.konsentrasiSoda(nilaiPH: 14) - 40) < 1e-9)
        #expect(abs(PenambahanSoda.konsentrasiSoda(nilaiPH: 13) - 4) < 1e-9)
    }

    @Test("Volume, soda dose and the per-ingredient split follow the dilution equation")
    func computesTheDose() throws {
        // C1 = 4 g/L (pH 13), C2 = 2 g/L, 1 L of water added: V_pakai = 2 x 1 / (4 - 2) = 1 L, V2 = 2 L.
        // dm = (30 - 2) x 2 = 56 g, split 20 : 10.
        let pH2 = 14 + log10(2.0 / 40)

        let soda = try #require(makeProyek().penambahanSoda(pHSebelum: 13, pHSesudah: pH2, airDitambahkanLiter: 1))

        #expect(abs(soda.volumeDipakai - 1) < 1e-9)
        #expect(abs(soda.volumeSekarang - 2) < 1e-9)
        #expect(abs(soda.gramSoda - 56) < 1e-9)
        #expect(soda.bahan.map(\.kode) == ["Soda Abu", "Soda Kostik"])
        #expect(abs(soda.bahan[0].gram - 56 * 20 / 30) < 1e-9)
        #expect(abs(soda.bahan[1].gram - 56 * 10 / 30) < 1e-9)
    }

    @Test("Nothing is added once the bath already has the target soda")
    func noNegativeDose() throws {
        // No auxiliaries in the recipe means a target of 0 g/L, which any C2 already meets.
        let soda = try #require(makeProyek(zatPembantu: []).penambahanSoda(
            pHSebelum: 13, pHSesudah: 12.5, airDitambahkanLiter: 1
        ))

        #expect(soda.gramSoda == 0)
        #expect(soda.bahan.isEmpty)
    }

    @Test("It cannot be computed when the pH did not drop enough, or without water or a recipe volume")
    func notComputable() {
        let proyek = makeProyek()

        #expect(proyek.penambahanSoda(pHSebelum: 12, pHSesudah: 12, airDitambahkanLiter: 1) == nil)
        #expect(proyek.penambahanSoda(pHSebelum: 12, pHSesudah: 12.5, airDitambahkanLiter: 1) == nil)
        #expect(proyek.penambahanSoda(pHSebelum: 13, pHSesudah: 12, airDitambahkanLiter: 0) == nil)
        #expect(makeProyek(air: 0).penambahanSoda(pHSebelum: 13, pHSesudah: 12, airDitambahkanLiter: 1) == nil)
    }
}
