//
//  BahanInputTests.swift
//  SeronaTests
//

@testable import Serona
import Testing

@Suite("BahanInput pilihan tanpa duplikat")
@MainActor
struct BahanInputTests {
    private let semua = ["Naphtol AS-G", "Naphtol AS-GR", "Naphtol AS-D"]

    @Test("A code used by another row is no longer offered")
    func usedCodeIsHiddenFromOtherRows() {
        let pertama = BahanInput(kode: "Naphtol AS-GR", gram: 5)
        let kedua = BahanInput()

        let pilihan = [pertama, kedua].pilihan(dari: semua, untukBaris: kedua.id)

        #expect(pilihan == ["Naphtol AS-G", "Naphtol AS-D"])
    }

    @Test("A row keeps its own code among its choices")
    func rowKeepsItsOwnCode() {
        let pertama = BahanInput(kode: "Naphtol AS-GR", gram: 5)
        let kedua = BahanInput(kode: "Naphtol AS-D", gram: 2)

        let pilihan = [pertama, kedua].pilihan(dari: semua, untukBaris: pertama.id)

        #expect(pilihan == ["Naphtol AS-G", "Naphtol AS-GR"])
    }

    @Test("Adding a row is possible only while a choice is left")
    func addNeedsAFreeChoice() {
        var daftar = [BahanInput(kode: "Naphtol AS-G", gram: 1), BahanInput(kode: "Naphtol AS-GR", gram: 1)]
        #expect(daftar.masihAdaPilihan(dari: semua))

        daftar.append(BahanInput(kode: "Naphtol AS-D", gram: 1))
        #expect(!daftar.masihAdaPilihan(dari: semua))
    }

    @Test("An empty row does not use up a choice")
    func emptyRowUsesNothing() {
        let daftar = [BahanInput(), BahanInput()]
        #expect(daftar.pilihan(dari: semua, untukBaris: daftar[0].id) == semua)
        #expect(daftar.masihAdaPilihan(dari: semua))
    }

    @Test("The same code twice is not valid, whatever the case or spacing")
    func duplicateCodeIsInvalid() {
        let sama = [BahanInput(kode: "Naphtol AS-G", gram: 5), BahanInput(kode: " naphtol as-g ", gram: 3)]
        #expect(!sama.valid)

        let beda = [BahanInput(kode: "Naphtol AS-G", gram: 5), BahanInput(kode: "Naphtol AS-D", gram: 3)]
        #expect(beda.valid)
    }
}
