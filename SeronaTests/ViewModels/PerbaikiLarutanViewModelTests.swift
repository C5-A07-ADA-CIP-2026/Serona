//
//  PerbaikiLarutanViewModelTests.swift
//  SeronaTests
//

import Foundation
@testable import Serona
import Testing

@MainActor
struct PerbaikiLarutanViewModelTests {
    @Test("Both readings low give the water, pH and concentration steps in that order")
    func stepsForBoth() {
        let viewModel = PerbaikiLarutanViewModel(issue: .keduanya)

        #expect(viewModel.steps == [.air, .phAir, .kepekatan])
    }

    @Test("A low pH alone skips the concentration step")
    func stepsForPH() {
        #expect(PerbaikiLarutanViewModel(issue: .phAir).steps == [.air, .phAir])
    }

    @Test("A low concentration alone skips the pH step")
    func stepsForKepekatan() {
        #expect(PerbaikiLarutanViewModel(issue: .kepekatan).steps == [.air, .kepekatan])
    }

    @Test("Starts on the first step with the default amount of water")
    func startsOnFirstStep() {
        let viewModel = PerbaikiLarutanViewModel(issue: .keduanya)

        #expect(viewModel.isActive(.air))
        #expect(!viewModel.isActive(.phAir))
        #expect(!viewModel.isDone(.air))
        #expect(viewModel.jumlahAir == 7)
        #expect(!viewModel.isFinished)
    }

    @Test("Next completes the current step and activates the following one")
    func nextAdvances() {
        let viewModel = PerbaikiLarutanViewModel(issue: .keduanya)

        viewModel.lanjut()

        #expect(viewModel.isDone(.air))
        #expect(viewModel.isActive(.phAir))
        #expect(!viewModel.isActive(.kepekatan))
        #expect(!viewModel.isFinished)
    }

    @Test("The last step finishes the guide and is labelled Selesai")
    func lastStepFinishes() {
        let viewModel = PerbaikiLarutanViewModel(issue: .phAir)
        #expect(viewModel.buttonTitle(for: .air) == "Selanjutnya")
        #expect(viewModel.buttonTitle(for: .phAir) == "Selesai")

        viewModel.lanjut()
        viewModel.lanjut()

        #expect(viewModel.isDone(.phAir))
        #expect(viewModel.isFinished)
    }

    private func makeProyek() -> Proyek {
        let resep = Resep(
            namaWarna: "Ungu", warnaHex: "#4B0082", air: 1000, kepekatan: 80, batasPH: 7,
            pewarna: [Bahan(kode: "Merah", gram: 5), Bahan(kode: "Biru", gram: 10)],
            zatPembantu: [Bahan(kode: "Soda Abu", gram: 30)]
        )
        return Proyek(nama: "Seragam", perangkatNama: "ESP 32", resep: resep, jumlahKain: 10)
    }

    @Test("Confirming the water reads the pH after it and works out the soda and the bath volume")
    func waterStepComputesSoda() throws {
        let viewModel = PerbaikiLarutanViewModel(issue: .keduanya, proyek: makeProyek(), pHSebelum: 13)
        viewModel.jumlahAir = 1

        viewModel.lanjut(waterPH: 14 + log10(2.0 / 40))

        let soda = try #require(viewModel.penambahanSoda)
        #expect(abs(soda.volumeSekarang - 2) < 1e-9)
        #expect(abs(soda.gramSoda - 56) < 1e-9)
    }

    @Test("The dye dose uses the bath volume found at the water step")
    func dyeUsesBathVolume() {
        let viewModel = PerbaikiLarutanViewModel(issue: .keduanya, proyek: makeProyek(), pHSebelum: 13)
        viewModel.jumlahAir = 1
        viewModel.lanjut(waterPH: 14 + log10(2.0 / 40))

        // C_target = 15 g/L, V2 = 2 L, 70%: 15 x 2 x 0.3 = 9 g, split 1 : 2.
        #expect(viewModel.volumeBakLiter != nil)
        let tambahan = viewModel.proyek?.pewarnaYangDitambah(kepekatan: 70, volumeLiter: viewModel.volumeBakLiter)

        #expect(tambahan?.map(\.kode) == ["Merah", "Biru"])
        #expect(abs((tambahan?[0].gram ?? 0) - 3) < 1e-9)
        #expect(abs((tambahan?[1].gram ?? 0) - 6) < 1e-9)
    }

    @Test("Without a pH before or after the water there is no soda, and the dye stays at the recipe volume")
    func withoutPHReadings() {
        let viewModel = PerbaikiLarutanViewModel(issue: .keduanya, proyek: makeProyek(), pHSebelum: nil)

        viewModel.lanjut(waterPH: 12)

        #expect(viewModel.penambahanSoda == nil)
        #expect(viewModel.volumeBakLiter == nil)
    }

    @Test("Next after finishing does nothing")
    func nextAfterFinishing() {
        let viewModel = PerbaikiLarutanViewModel(issue: .kepekatan)
        viewModel.lanjut()
        viewModel.lanjut()

        viewModel.lanjut()

        #expect(viewModel.isFinished)
        #expect(viewModel.isDone(.kepekatan))
    }
}
