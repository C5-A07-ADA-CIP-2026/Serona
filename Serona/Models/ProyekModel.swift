import Foundation
import SwiftData

enum ProyekStatus: String, Codable {
    case aktif
    case nonaktif
}

@Model
final class Proyek {
    var id: UUID

    var namaTersimpan: String?
    var statusTersimpan: ProyekStatus?
    var perangkatNamaTersimpan: String?

    var perangkatID: UUID?
    var pewarnaTersimpan: [Bahan]?
    var zatPembantuTersimpan: [Bahan]?

    var airTersimpan: Int?

    var airResepTersimpan: Int?
    var tanggal: Date
    var namaWarna: String
    var warnaHex: String?
    var batasKepekatan: Double
    var batasPH: Double
    var jumlahKain: Int
    var kepekatanAkhir: Double?
    var phAkhir: Double?

    var visibleAverageAwal: Double?

    var rasioAwal: [Double]?

    var rasioAirBersih: [Double]?
    var phAwal: Double?
    @Relationship(deleteRule: .nullify) var resep: Resep?

    var status: ProyekStatus {
        get { statusTersimpan ?? .nonaktif }
        set { statusTersimpan = newValue }
    }

    var nama: String {
        get { namaTersimpan ?? namaWarna }
        set { namaTersimpan = newValue }
    }

    var perangkatNama: String {
        get { perangkatNamaTersimpan ?? "" }
        set { perangkatNamaTersimpan = newValue }
    }

    var pewarna: [Bahan] {
        get { pewarnaTersimpan ?? [] }
        set { pewarnaTersimpan = newValue }
    }

    var zatPembantu: [Bahan] {
        get { zatPembantuTersimpan ?? [] }
        set { zatPembantuTersimpan = newValue }
    }

    var air: Int {
        get { airTersimpan ?? resep?.air ?? 0 }
        set { airTersimpan = newValue }
    }

    init(
        nama: String,
        perangkatNama: String,
        perangkatID: UUID? = nil,
        resep: Resep,
        jumlahKain: Int = 1,
        tanggal: Date = .now
    ) {
        id = UUID()
        namaTersimpan = nama
        statusTersimpan = .aktif
        perangkatNamaTersimpan = perangkatNama
        self.perangkatID = perangkatID
        self.tanggal = tanggal
        namaWarna = resep.namaWarna
        warnaHex = resep.warnaHex
        batasKepekatan = resep.kepekatan
        batasPH = resep.batasPH
        pewarnaTersimpan = resep.pewarna
        zatPembantuTersimpan = resep.zatPembantu
        airTersimpan = resep.air
        airResepTersimpan = resep.air
        self.jumlahKain = jumlahKain
        self.resep = resep
    }

    func selesaikan(kepekatanAkhir _: Double? = nil, phAkhir _: Double? = nil) {
        guard status == .aktif else { return }
        kepekatanAkhir = nil
        phAkhir = nil
        visibleAverageAwal = nil
        rasioAwal = nil
        rasioAirBersih = nil
        phAwal = nil
        perangkatNamaTersimpan = ""
        perangkatID = nil
        pewarnaTersimpan = []
        zatPembantuTersimpan = []
        airTersimpan = nil
        airResepTersimpan = nil
        namaWarna = "-"
        warnaHex = nil
        resep = nil
        status = .nonaktif
    }

    var volumeResepLiter: Double {
        Double(airResepTersimpan ?? resep?.air ?? air)
    }

    var volumeAwalLiter: Double {
        Double(air > 0 ? air : (airResepTersimpan ?? resep?.air ?? 0))
    }

    var targetPewarnaGramPerLiter: Double {
        guard volumeResepLiter > 0 else { return 0 }
        return pewarna.reduce(0) { $0 + $1.gram } / volumeResepLiter
    }

    func konsentrasiPewarnaGramPerLiter(kepekatan percent: Double) -> Double {
        targetPewarnaGramPerLiter * max(0, percent) / 100
    }

    func pewarnaYangDitambah(kepekatan percent: Double, volumeLiter: Double? = nil) -> [Bahan] {
        var volume = volumeAwalLiter
        if let volumeLiter, volumeLiter > 0 {
            volume = volumeLiter
        }
        let totalGram = max(0, targetPewarnaGramPerLiter - konsentrasiPewarnaGramPerLiter(kepekatan: percent)) * volume
        let totalResep = pewarna.reduce(0) { $0 + $1.gram }
        return pewarna.map { Bahan(kode: $0.kode, gram: totalResep > 0 ? totalGram * $0.gram / totalResep : 0) }
    }

    func batalkanSelesai() {
        kepekatanAkhir = nil
        phAkhir = nil
        status = .aktif
    }
}

extension Bahan {
    static func formatBerat(gram: Double) -> String {
        let dibulatkan = gram.rounded(.up)
        guard dibulatkan >= 1000 else { return String(format: "%.0fgr", dibulatkan) }
        return String(format: "%gkg", dibulatkan / 1000)
    }
}

struct ProyekDaftar {
    let aktif: [Proyek]
    let nonaktif: [Proyek]

    init(_ semua: [Proyek]) {
        let terbaruDulu = semua.sorted { $0.tanggal > $1.tanggal }
        aktif = terbaruDulu.filter { $0.status == .aktif }
        nonaktif = terbaruDulu.filter { $0.status == .nonaktif }
    }

    var isEmpty: Bool {
        aktif.isEmpty && nonaktif.isEmpty
    }
}
