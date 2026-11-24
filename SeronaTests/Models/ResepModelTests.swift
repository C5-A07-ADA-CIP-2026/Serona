@testable import Serona
import Testing

@Suite("Resep search")
@MainActor
struct ResepModelTests {
    private let daftar: [Resep] = [
        Resep(
            namaWarna: "Merah Marun", warnaHex: "#B50202",
            air: 1000, kepekatan: 80, batasPH: 7
        ),
        Resep(
            namaWarna: "Biru Laut", warnaHex: "#0044AA",
            air: 1000, kepekatan: 80, batasPH: 7
        ),
    ]

    @Test("Matches namaWarna ignoring case")
    func matchesNamaWarna() {
        #expect(daftar.cari("marun").map(\.namaWarna) == ["Merah Marun"])
    }

    @Test("Blank or whitespace text returns everything")
    func blankReturnsAll() {
        #expect(daftar.cari("").count == 2)
        #expect(daftar.cari("   ").count == 2)
    }

    @Test("Unmatched text returns nothing")
    func unmatchedReturnsEmpty() {
        #expect(daftar.cari("zzz").isEmpty)
    }

    @Test("Keeps the original order")
    func keepsOrder() {
        #expect(daftar.cari("u").map(\.namaWarna) == ["Merah Marun", "Biru Laut"])
    }
}
