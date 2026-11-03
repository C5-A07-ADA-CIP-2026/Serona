//
//  PenambahanPewarnaTests.swift
//  SeronaTests
//

@testable import Serona
import Testing

/// Dye to add = the recipe's dye for all the cloth x (1 - concentration / 100), split like the recipe.
@Suite("Penambahan pewarna")
@MainActor
struct PenambahanPewarnaTests {
    private func makeProyek(jumlahKain: Int = 10) -> Proyek {
        let resep = Resep(
            namaWarna: "Ungu", warnaHex: "#4B0082", air: 1000, kepekatan: 80, batasPH: 7,
            pewarna: [Bahan(kode: "Merah", gram: 5), Bahan(kode: "Biru", gram: 10)]
        )
        return Proyek(nama: "Seragam", perangkatNama: "ESP 32", resep: resep, jumlahKain: jumlahKain)
    }

    @Test("70% means 30% of the recipe's dye for the cloth, split by ingredient")
    func addsTheMissingShare() {
        let tambahan = makeProyek().pewarnaYangDitambah(kepekatan: 70)

        #expect(tambahan.map(\.kode) == ["Merah", "Biru"])
        #expect(abs(tambahan[0].gram - 15) < 1e-9)
        #expect(abs(tambahan[1].gram - 30) < 1e-9)
    }

    @Test("At or above 100% nothing is added")
    func nothingAtFullConcentration() {
        #expect(makeProyek().pewarnaYangDitambah(kepekatan: 100).allSatisfy { $0.gram == 0 })
        #expect(makeProyek().pewarnaYangDitambah(kepekatan: 120).allSatisfy { $0.gram == 0 })
    }

    @Test("With the bath volume after the soda step the dose scales from the recipe volume")
    func scalesWithTheBathVolume() {
        // Recipe water 1000 mL per cloth x 10 cloths = 10 L; C_target = 150 g / 10 L = 15 g/L.
        // At 70% in 20 L: 15 x 20 x 0.3 = 90 g, split 1 : 2 like the recipe.
        let tambahan = makeProyek().pewarnaYangDitambah(kepekatan: 70, volumeLiter: 20)

        #expect(abs(tambahan[0].gram - 30) < 1e-9)
        #expect(abs(tambahan[1].gram - 60) < 1e-9)
    }

    @Test("Without a usable volume the dose stays at the recipe volume")
    func ignoresMissingVolume() {
        let proyek = makeProyek()
        let tanpaVolume = proyek.pewarnaYangDitambah(kepekatan: 70)

        #expect(proyek.pewarnaYangDitambah(kepekatan: 70, volumeLiter: nil) == tanpaVolume)
        #expect(proyek.pewarnaYangDitambah(kepekatan: 70, volumeLiter: 0) == tanpaVolume)
    }

    @Test("Weights show in grams, rounded up, and in kg from 1000 grams")
    func formatsWeights() {
        #expect(Bahan.formatBerat(gram: 30) == "30gr")
        #expect(Bahan.formatBerat(gram: 12.2) == "13gr")
        #expect(Bahan.formatBerat(gram: 999.5) == "1kg")
        #expect(Bahan.formatBerat(gram: 1500) == "1.5kg")
    }
}
