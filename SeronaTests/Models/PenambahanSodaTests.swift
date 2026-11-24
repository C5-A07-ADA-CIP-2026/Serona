import Foundation
@testable import Serona
import Testing

@Suite("Penambahan soda")
@MainActor
struct PenambahanSodaTests {
    private static let zatBawaan = [Bahan(kode: "Soda Abu", gram: 20), Bahan(kode: "Soda Kostik", gram: 10)]

    private func makeProyek(zatPembantu: [Bahan] = zatBawaan, air: Int = 1) -> Proyek {
        let resep = Resep(
            namaWarna: "Ungu", warnaHex: "#4B0082", air: air, kepekatan: 80, batasPH: 7,
            pewarna: [Bahan(kode: "Merah", gram: 5)], zatPembantu: zatPembantu
        )
        return Proyek(nama: "Seragam", perangkatNama: "ESP 32", resep: resep)
    }

    @Test("Soda concentration from pH is 10^(pH - 14) x 40 g/L")
    func sodaConcentration() {
        #expect(abs(PenambahanSoda.konsentrasiSoda(nilaiPH: 14) - 40) < 1e-9)
        #expect(abs(PenambahanSoda.konsentrasiSoda(nilaiPH: 13) - 4) < 1e-9)
    }

    @Test("Volume, soda dose and the per-ingredient split follow the dilution equation")
    func computesTheDose() throws {
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
