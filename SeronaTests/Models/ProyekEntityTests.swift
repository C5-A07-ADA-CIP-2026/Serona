import Foundation
@testable import Serona
import SwiftData
import Testing

@Suite("Proyek entity")
@MainActor
struct ProyekEntityTests {
    @Test("Copies the recipe snapshot")
    func proyekCopiesRecipeSnapshot() {
        let resep = Resep.sample(namaWarna: "Merah Marun", warnaHex: "#B50202")

        let proyek = Proyek(nama: "A", perangkatNama: "ESP 32", resep: resep, jumlahKain: 3)

        #expect(proyek.namaWarna == "Merah Marun")
        #expect(proyek.warnaHex == "#B50202")
        #expect(proyek.batasKepekatan == 80)
        #expect(proyek.batasPH == 7)
        #expect(proyek.jumlahKain == 3)
        #expect(proyek.resep === resep)
    }

    @Test("Keeps the snapshot when the recipe is deleted")
    func deletingResepKeepsProyekSnapshot() throws {
        let context = try makeTestContext()
        let resep = Resep.sample(namaWarna: "Merah Marun", warnaHex: "#B50202")
        let proyek = Proyek(nama: "A", perangkatNama: "ESP 32", resep: resep, jumlahKain: 3)
        context.insert(resep)
        context.insert(proyek)
        try context.save()

        context.delete(resep)
        try context.save()

        let hasil = try context.fetch(FetchDescriptor<Proyek>())
        #expect(hasil.count == 1)
        #expect(hasil.first?.resep == nil)
        #expect(hasil.first?.namaWarna == "Merah Marun")
        #expect(hasil.first?.batasKepekatan == 80)
    }

    @Test("Persists pewarna and zat pembantu")
    func resepPersistsBahan() throws {
        let context = try makeTestContext()
        let pewarna = [Bahan(kode: "Naphtol AS", gram: 5)]
        let zatPembantu = [Bahan(kode: "Kostik", gram: 2)]
        let resep = Resep(
            namaWarna: "Ungu",
            warnaHex: "#4B0082",
            air: 1000,
            kepekatan: 80,
            batasPH: 7,
            pewarna: pewarna,
            zatPembantu: zatPembantu
        )
        context.insert(resep)
        try context.save()

        let hasil = try context.fetch(FetchDescriptor<Resep>())
        #expect(hasil.first?.pewarna == pewarna)
        #expect(hasil.first?.zatPembantu == zatPembantu)
    }

    @Test("Builds an in-memory container")
    func schemaBuildsInMemoryContainer() throws {
        _ = try SeronaSchema.makeContainer(inMemory: true)
    }
}
