@testable import Serona
import Testing

@Suite("Penambahan pewarna")
@MainActor
struct PenambahanPewarnaTests {
    private func makeProyek() -> Proyek {
        let resep = Resep(
            namaWarna: "Ungu", warnaHex: "#4B0082", air: 1, kepekatan: 80, batasPH: 7,
            pewarna: [Bahan(kode: "Merah", gram: 5), Bahan(kode: "Biru", gram: 10)]
        )
        return Proyek(nama: "Seragam", perangkatNama: "ESP 32", resep: resep)
    }

    @Test("70% means 30% of the recipe's dye for its volume, split by ingredient")
    func addsTheMissingShare() {
        let tambahan = makeProyek().pewarnaYangDitambah(kepekatan: 70)

        #expect(tambahan.map(\.kode) == ["Merah", "Biru"])
        #expect(abs(tambahan[0].gram - 1.5) < 1e-9)
        #expect(abs(tambahan[1].gram - 3) < 1e-9)
    }

    @Test("At or above 100% nothing is added")
    func nothingAtFullConcentration() {
        #expect(makeProyek().pewarnaYangDitambah(kepekatan: 100).allSatisfy { $0.gram == 0 })
        #expect(makeProyek().pewarnaYangDitambah(kepekatan: 120).allSatisfy { $0.gram == 0 })
    }

    @Test("With the bath volume after the soda step the dose scales from the recipe volume")
    func scalesWithTheBathVolume() {
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

    @Test("The target is the recipe's dye over its water in g/L; the bath holds that share of it")
    func dyeConcentrationInGramPerLiter() {
        let proyek = makeProyek()

        #expect(abs(proyek.targetPewarnaGramPerLiter - 15) < 1e-9)
        #expect(abs(proyek.konsentrasiPewarnaGramPerLiter(kepekatan: 100) - 15) < 1e-9)
        #expect(abs(proyek.konsentrasiPewarnaGramPerLiter(kepekatan: 70) - 10.5) < 1e-9)
    }

    @Test("Dose = (target - bath g/L) x bath volume, the same as the missing share of the recipe")
    func doseFollowsGramPerLiter() {
        let proyek = makeProyek()
        let selisih = proyek.targetPewarnaGramPerLiter - proyek.konsentrasiPewarnaGramPerLiter(kepekatan: 70)
        let total = proyek.pewarnaYangDitambah(kepekatan: 70, volumeLiter: 20).reduce(0) { $0 + $1.gram }

        #expect(abs(total - selisih * 20) < 1e-9)
    }
}
