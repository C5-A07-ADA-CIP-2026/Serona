import Foundation

struct PenambahanSoda: Equatable {
    let volumeDipakai: Double

    let volumeSekarang: Double

    let konsentrasiSebelum: Double
    let konsentrasiSesudah: Double

    let gramSoda: Double
    let bahan: [Bahan]

    static func konsentrasiSoda(nilaiPH: Double) -> Double {
        pow(10, nilaiPH - 14) * 40
    }

    static let selisihMinimum = 0.0001
}

@MainActor
extension Proyek {
    var targetSodaGramPerLiter: Double {
        guard volumeResepLiter > 0 else { return 0 }
        return zatPembantu.reduce(0) { $0 + $1.gram } / volumeResepLiter
    }

    func penambahanSoda(pHSebelum: Double, pHSesudah: Double, airDitambahkanLiter: Double) -> PenambahanSoda? {
        guard airDitambahkanLiter > 0, volumeResepLiter > 0, pHSebelum - pHSesudah >= 0.01 else { return nil }
        let sebelum = PenambahanSoda.konsentrasiSoda(nilaiPH: pHSebelum)
        let sesudah = PenambahanSoda.konsentrasiSoda(nilaiPH: pHSesudah)
        guard sebelum > sesudah else { return nil }

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
