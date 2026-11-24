import Observation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class FormResepViewModel {
    var namaWarna = ""
    var ukuranAir: Int?
    var kepekatan: Double?
    var batasPH: Double?
    var warnaDipilih: Color?
    var pewarna = [BahanInput()]
    var zatPembantu = [BahanInput()]

    let daftarPilihanPewarna = [
        "AS-G", "AS-LB", "AS", "AS-D", "AS-OL",
        "AS-BS", "AS-BO", "AS-BR", "AS-GR", "Soga 91",
    ]
    let daftarPilihanZatPembantu = ["Kostik", "Abu"]

    private(set) var resepAsli: Resep?

    var sedangMengedit: Bool {
        resepAsli != nil
    }

    var formLengkap: Bool {
        namaWarna.tidakKosong

            && (ukuranAir ?? 0) > 0
            && (kepekatan ?? 0) > 0
            && (batasPH ?? 0) > 0
            && pewarna.valid
            && zatPembantu.valid
    }

    func pilihanPewarna(untuk baris: BahanInput) -> [String] {
        pewarna.pilihan(dari: daftarPilihanPewarna, untukBaris: baris.id)
    }

    func pilihanZatPembantu(untuk baris: BahanInput) -> [String] {
        zatPembantu.pilihan(dari: daftarPilihanZatPembantu, untukBaris: baris.id)
    }

    var bisaTambahPewarna: Bool {
        pewarna.semuaTerisi && pewarna.masihAdaPilihan(dari: daftarPilihanPewarna)
    }

    var bisaTambahZatPembantu: Bool {
        zatPembantu.semuaTerisi && zatPembantu.masihAdaPilihan(dari: daftarPilihanZatPembantu)
    }

    var adaPerubahan: Bool {
        guard let asli = resepAsli, !asli.isDeleted else { return false }
        return namaWarna != asli.namaWarna

            || ukuranAir != asli.air
            || kepekatan != asli.kepekatan
            || batasPH != asli.batasPH
            || pewarna.barisTerisi.map(\.bahan) != asli.pewarna
            || zatPembantu.barisTerisi.map(\.bahan) != asli.zatPembantu
    }

    var bisaSimpan: Bool {
        sedangMengedit ? (formLengkap && adaPerubahan) : formLengkap
    }

    init() {}

    init(resep: Resep) {
        resepAsli = resep
        namaWarna = resep.namaWarna

        ukuranAir = resep.air
        kepekatan = resep.kepekatan
        batasPH = resep.batasPH
        pewarna = resep.pewarna.map { BahanInput(kode: $0.kode, gram: $0.gram) }
        zatPembantu = resep.zatPembantu.map { BahanInput(kode: $0.kode, gram: $0.gram) }
    }

    func simpan(context: some ModelPersisting) throws {
        guard formLengkap,

              let air = ukuranAir,
              let kepekatan,
              let batasPH
        else { return }

        if let resep = resepAsli {
            resep.namaWarna = namaWarna

            resep.air = air
            resep.kepekatan = kepekatan
            resep.batasPH = batasPH
            resep.pewarna = pewarna.barisTerisi.map(\.bahan)
            resep.zatPembantu = zatPembantu.barisTerisi.map(\.bahan)
            try context.save()
        } else {
            let resep = Resep(
                namaWarna: namaWarna,
                warnaHex: nil,
                air: air,
                kepekatan: kepekatan,
                batasPH: batasPH,
                pewarna: pewarna.barisTerisi.map(\.bahan),
                zatPembantu: zatPembantu.barisTerisi.map(\.bahan)
            )
            try context.insertAndSave(resep)
        }
    }

    func hapus(context: some ModelPersisting) throws {
        guard let resep = resepAsli else { return }
        context.delete(resep)
        try context.save()
    }
}
