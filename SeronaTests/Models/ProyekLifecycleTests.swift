import Foundation
@testable import Serona
import SwiftData
import Testing

@Suite("Proyek lifecycle")
@MainActor
struct ProyekLifecycleTests {
    private func makeResep() -> Resep {
        Resep(
            namaWarna: "Merah Marun", warnaHex: "#B50202",
            air: 1000, kepekatan: 80, batasPH: 7,
            pewarna: [Bahan(kode: "Naphtol AS", gram: 5)],
            zatPembantu: [Bahan(kode: "Kostik", gram: 2)]
        )
    }

    @Test("A new project is active, unscanned and snapshots the recipe")
    func newProyekIsActiveWithSnapshot() {
        let resep = makeResep()

        let proyek = Proyek(nama: "Seragam RT 5", perangkatNama: "ESP 32", resep: resep, jumlahKain: 3)

        #expect(proyek.nama == "Seragam RT 5")
        #expect(proyek.perangkatNama == "ESP 32")
        #expect(proyek.status == .aktif)
        #expect(proyek.jumlahKain == 3)
        #expect(proyek.namaWarna == "Merah Marun")
        #expect(proyek.warnaHex == "#B50202")
        #expect(proyek.batasKepekatan == 80)
        #expect(proyek.batasPH == 7)
        #expect(proyek.pewarna == [Bahan(kode: "Naphtol AS", gram: 5)])
        #expect(proyek.zatPembantu == [Bahan(kode: "Kostik", gram: 2)])
        #expect(proyek.kepekatanAkhir == nil)
        #expect(proyek.phAkhir == nil)
        #expect(proyek.resep === resep)
    }

    @Test("Finishing makes the project inactive and clears the bath data")
    func selesaikanMakesProyekInactive() {
        let proyek = Proyek(nama: "A", perangkatNama: "ESP 32", resep: makeResep(), jumlahKain: 1)

        proyek.selesaikan(kepekatanAkhir: 85, phAkhir: 6.5)

        #expect(proyek.status == .nonaktif)
        #expect(proyek.kepekatanAkhir == nil)
        #expect(proyek.phAkhir == nil)
        #expect(proyek.namaWarna == "-")
        #expect(proyek.perangkatNama == "")
        #expect(proyek.resep == nil)
    }

    @Test("Final readings stay nil, never 0, when the sensor sent none")
    func selesaikanKeepsMissingReadingsNil() {
        let proyek = Proyek(nama: "A", perangkatNama: "ESP 32", resep: makeResep(), jumlahKain: 1)

        proyek.selesaikan(kepekatanAkhir: nil, phAkhir: nil)

        #expect(proyek.status == .nonaktif)
        #expect(proyek.kepekatanAkhir == nil)
        #expect(proyek.phAkhir == nil)
    }

    @Test("Finishing an inactive project again changes nothing")
    func selesaikanIsIdempotent() {
        let proyek = Proyek(nama: "A", perangkatNama: "ESP 32", resep: makeResep(), jumlahKain: 1)
        proyek.selesaikan()

        proyek.selesaikan(kepekatanAkhir: 10, phAkhir: 2)

        #expect(proyek.status == .nonaktif)
        #expect(proyek.kepekatanAkhir == nil)
        #expect(proyek.phAkhir == nil)
    }

    @Test("A project saved before these fields existed is an inactive history entry named after its color")
    func legacyProyekReadsAsInactiveHistory() {
        let proyek = Proyek(nama: "A", perangkatNama: "ESP 32", resep: makeResep(), jumlahKain: 1)
        proyek.namaTersimpan = nil
        proyek.statusTersimpan = nil
        proyek.perangkatNamaTersimpan = nil
        proyek.pewarnaTersimpan = nil
        proyek.zatPembantuTersimpan = nil

        #expect(proyek.nama == "Merah Marun")
        #expect(proyek.status == .nonaktif)
        #expect(proyek.perangkatNama == "")
        #expect(proyek.pewarna.isEmpty)
        #expect(proyek.zatPembantu.isEmpty)
    }

    @Test("Status and name survive a save and fetch, and the cleared bath data stays cleared")
    func lifecyclePersists() throws {
        let context = try makeTestContext()
        let proyek = Proyek(nama: "Seragam RT 5", perangkatNama: "ESP 32", resep: makeResep(), jumlahKain: 2)
        proyek.selesaikan(kepekatanAkhir: 90, phAkhir: 7)
        try context.insertAndSave(proyek)

        let hasil = try #require(try context.fetch(FetchDescriptor<Proyek>()).first)

        #expect(hasil.nama == "Seragam RT 5")
        #expect(hasil.perangkatNama == "")
        #expect(hasil.status == .nonaktif)
        #expect(hasil.pewarna.isEmpty)
        #expect(hasil.zatPembantu.isEmpty)
    }
}

@Suite("ProyekDaftar")
@MainActor
struct ProyekDaftarTests {
    private func makeProyek(_ nama: String, daysAgo: Double, selesai: Bool = false) -> Proyek {
        let resep = Resep.sample()
        let proyek = Proyek(
            nama: nama, perangkatNama: "ESP 32", resep: resep, jumlahKain: 1,
            tanggal: Date(timeIntervalSince1970: 1_800_000_000 - daysAgo * 86400)
        )
        if selesai {
            proyek.selesaikan(kepekatanAkhir: 90, phAkhir: 7)
        }
        return proyek
    }

    @Test("Splits active and inactive projects, newest first")
    func splitsByStatusNewestFirst() {
        let lama = makeProyek("Lama", daysAgo: 5)
        let baru = makeProyek("Baru", daysAgo: 1)
        let selesaiLama = makeProyek("Selesai lama", daysAgo: 9, selesai: true)
        let selesaiBaru = makeProyek("Selesai baru", daysAgo: 3, selesai: true)

        let daftar = ProyekDaftar([lama, selesaiLama, baru, selesaiBaru])

        #expect(daftar.aktif.map(\.nama) == ["Baru", "Lama"])
        #expect(daftar.nonaktif.map(\.nama) == ["Selesai baru", "Selesai lama"])
    }

    @Test("Bak cards are ordered alphabetically, not by creation date, and numbers sort naturally")
    func ordersAlphabetically() {
        let bak10 = makeProyek("Bak 10", daysAgo: 9)
        let bak2 = makeProyek("Bak 2", daysAgo: 1)
        let bak1 = makeProyek("Bak 1", daysAgo: 5)
        let alfa = makeProyek("alfa", daysAgo: 3)

        let urut = [bak10, bak2, bak1, alfa].diurutkanAbjad()

        #expect(urut.map(\.nama) == ["alfa", "Bak 1", "Bak 2", "Bak 10"])
    }

    @Test("Equal names fall back to the older project first")
    func equalNamesKeepCreationOrder() {
        let baru = makeProyek("Bak 1", daysAgo: 1)
        let lama = makeProyek("Bak 1", daysAgo: 5)

        #expect([baru, lama].diurutkanAbjad() == [lama, baru])
    }

    @Test("An empty list is empty")
    func emptyList() {
        let daftar = ProyekDaftar([])

        #expect(daftar.isEmpty)
        #expect(daftar.aktif.isEmpty)
        #expect(daftar.nonaktif.isEmpty)
    }

    @Test("A list with only inactive projects is not empty")
    func onlyInactiveIsNotEmpty() {
        let daftar = ProyekDaftar([makeProyek("Selesai", daysAgo: 1, selesai: true)])

        #expect(!daftar.isEmpty)
        #expect(daftar.aktif.isEmpty)
    }
}
