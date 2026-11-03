//
//  PenambahanSodaModel.swift
//  Serona
//

import Foundation

/// The soda to add after water was added to the bath, worked out from the pH before and after the water.
struct PenambahanSoda: Equatable {
    /// Bath volume before the water was added (L), from C1 x V = C2 x (V + V_air).
    let volumeDipakai: Double
    /// Bath volume after the water was added (L): V2.
    let volumeSekarang: Double
    /// Soda concentration before and after the water (g/L).
    let konsentrasiSebelum: Double
    let konsentrasiSesudah: Double
    /// Soda to add (g), split by auxiliary like the recipe in `bahan`.
    let gramSoda: Double
    let bahan: [Bahan]

    /// Soda (NaOH, 40 g/mol) concentration in g/L from the pH: 10^(pH - 14) x 40.
    static func konsentrasiSoda(nilaiPH: Double) -> Double {
        pow(10, nilaiPH - 14) * 40
    }

    /// Differences in concentration at or below this cannot give a volume.
    static let selisihMinimum = 0.0001
}

@MainActor
extension Proyek {
    /// The soda target (g/L): the recipe's auxiliaries for all the cloth over the recipe water.
    var targetSodaGramPerLiter: Double {
        guard volumeResepLiter > 0 else { return 0 }
        return zatPembantu.reduce(0) { $0 + $1.gram } * Double(jumlahKain) / volumeResepLiter
    }

    /// The soda to add after `airDitambahkanLiter` of water took the pH from `pHSebelum` to `pHSesudah`.
    /// Nil when the pH did not drop enough to tell the bath volume, or there is no water or recipe volume.
    func penambahanSoda(pHSebelum: Double, pHSesudah: Double, airDitambahkanLiter: Double) -> PenambahanSoda? {
        guard airDitambahkanLiter > 0, volumeResepLiter > 0 else { return nil }
        let sebelum = PenambahanSoda.konsentrasiSoda(nilaiPH: pHSebelum)
        let sesudah = PenambahanSoda.konsentrasiSoda(nilaiPH: pHSesudah)
        guard sebelum - sesudah > PenambahanSoda.selisihMinimum else { return nil }

        let volumeDipakai = sesudah * airDitambahkanLiter / (sebelum - sesudah)
        let volumeSekarang = volumeDipakai + airDitambahkanLiter
        let gram = max(0, (targetSodaGramPerLiter - sesudah) * volumeSekarang)

        let totalZat = zatPembantu.reduce(0) { $0 + $1.gram }
        let bahan = zatPembantu.map {
            Bahan(kode: $0.kode, gram: totalZat > 0 ? gram * $0.gram / totalZat : 0)
        }
        return PenambahanSoda(
            volumeDipakai: volumeDipakai,
            volumeSekarang: volumeSekarang,
            konsentrasiSebelum: sebelum,
            konsentrasiSesudah: sesudah,
            gramSoda: gram,
            bahan: bahan
        )
    }
}
