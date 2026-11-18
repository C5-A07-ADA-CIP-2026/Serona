//
//  ResepViewModel.swift
//  Serona
//
//  Created by Dina on 22/10/26.
//

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

    /// Resep yang sedang dilihat. `nil` berarti mode tambah.
    private(set) var resepAsli: Resep?

    var sedangMengedit: Bool {
        resepAsli != nil
    }

    var formLengkap: Bool {
        namaWarna.tidakKosong
//            && warnaDipilih != nil
            && (ukuranAir ?? 0) > 0
            && (kepekatan ?? 0) > 0
            && (batasPH ?? 0) > 0
            && pewarna.valid
            && zatPembantu.valid
    }

    /// Kode yang sudah dipilih baris lain tidak ditawarkan lagi, supaya pewarna tidak dobel.
    func pilihanPewarna(untuk baris: BahanInput) -> [String] {
        pewarna.pilihan(dari: daftarPilihanPewarna, untukBaris: baris.id)
    }

    func pilihanZatPembantu(untuk baris: BahanInput) -> [String] {
        zatPembantu.pilihan(dari: daftarPilihanZatPembantu, untukBaris: baris.id)
    }

    /// Baris baru hanya berguna kalau baris terakhir sudah lengkap dan masih ada kode yang belum dipakai.
    var bisaTambahPewarna: Bool {
        pewarna.semuaTerisi && pewarna.masihAdaPilihan(dari: daftarPilihanPewarna)
    }

    var bisaTambahZatPembantu: Bool {
        zatPembantu.semuaTerisi && zatPembantu.masihAdaPilihan(dari: daftarPilihanZatPembantu)
    }

    /// `true` kalau ada isian yang berbeda dari resep asli.
    var adaPerubahan: Bool {
        guard let asli = resepAsli, !asli.isDeleted else { return false }
        return namaWarna != asli.namaWarna
//            || warnaDipilih?.hexString != asli.warnaHex
            || ukuranAir != asli.air
            || kepekatan != asli.kepekatan
            || batasPH != asli.batasPH
            || pewarna.barisTerisi.map(\.bahan) != asli.pewarna
            || zatPembantu.barisTerisi.map(\.bahan) != asli.zatPembantu
    }

    /// Tombol centang aktif (biru) hanya kalau form valid dan ada yang berubah.
    var bisaSimpan: Bool {
        sedangMengedit ? (formLengkap && adaPerubahan) : formLengkap
    }

    init() {}

    /// Mengisi form dari resep yang sudah tersimpan (untuk mode baca).
    init(resep: Resep) {
        resepAsli = resep
        namaWarna = resep.namaWarna
//        warnaDipilih = Color(hex: resep.warnaHex)
        ukuranAir = resep.air
        kepekatan = resep.kepekatan
        batasPH = resep.batasPH
        pewarna = resep.pewarna.map { BahanInput(kode: $0.kode, gram: $0.gram) }
        zatPembantu = resep.zatPembantu.map { BahanInput(kode: $0.kode, gram: $0.gram) }
    }

    /// Menyimpan form sebagai `Resep` baru. Tidak melakukan apa pun bila form belum lengkap.
    func simpan(context: some ModelPersisting) throws {
        guard formLengkap,
//              let warna = warnaDipilih,
              let air = ukuranAir,
              let kepekatan,
              let batasPH
        else { return }

        if let resep = resepAsli {
            resep.namaWarna = namaWarna
//            resep.warnaHex = warna.hexString
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
