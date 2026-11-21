//
//  ProyekModel.swift
//  Serona
//

import Foundation
import SwiftData

enum ProyekStatus: String, Codable {
    case aktif
    case nonaktif
}

@Model
final class Proyek {
    var id: UUID
    /// Stored optional: rows saved before these fields existed come out of the store with NULL.
    var namaTersimpan: String?
    var statusTersimpan: ProyekStatus?
    var perangkatNamaTersimpan: String?
    /// Stable CoreBluetooth identifier for the sensor assigned to this bath.
    /// Older projects have no identifier and must ask the user to select a sensor again.
    var perangkatID: UUID?
    var pewarnaTersimpan: [Bahan]?
    var zatPembantuTersimpan: [Bahan]?
    /// Bath water volume in Liters (L) entered when starting the project.
    var airTersimpan: Int?
    /// Recipe reference water volume in Liters (L), copied from `resep.air` so edits/deletes do not alter g/L targets.
    var airResepTersimpan: Int?
    var tanggal: Date
    var namaWarna: String
    var warnaHex: String?
    var batasKepekatan: Double
    var batasPH: Double
    var jumlahKain: Int
    var kepekatanAkhir: Double?
    var phAkhir: Double?
    /// The baseline read when the scan started (nil until then). Its presence marks the project as scanned,
    /// so reopening it resumes at the same stage.
    var visibleAverageAwal: Double?
    /// The channel / clear ratios of that baseline reading, which the concentration is measured against.
    /// Nil for projects set before the device sent channels; they keep using `visibleAverageAwal`.
    var rasioAwal: [Double]?
    /// The channel / clear ratios of clean water, the reference the absorbance of the bath is measured against.
    /// Nil until the user sets it; without it the concentration keeps the older, baseline-only formula.
    var rasioAirBersih: [Double]?
    var phAwal: Double?
    @Relationship(deleteRule: .nullify) var resep: Resep?

    /// A project from before the lifecycle existed was saved finished, so it reads as inactive.
    var status: ProyekStatus {
        get { statusTersimpan ?? .nonaktif }
        set { statusTersimpan = newValue }
    }

    /// Falls back to the color name for projects saved without a name.
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

    /// Bath water volume in Liters (L).
    var air: Int {
        get { airTersimpan ?? resep?.air ?? 0 }
        set { airTersimpan = newValue }
    }

    /// A new, active project. Name, colour, limits and ingredients are copied from `resep`,
    /// so the project stays correct when the recipe is edited or deleted.
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

    /// Deletes all saved bath data and resets the bak to unused (`nonaktif`).
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

    /// The recipe's reference water volume in liters (e.g., 3 L).
    var volumeResepLiter: Double {
        Double(airResepTersimpan ?? resep?.air ?? air)
    }

    /// The initial water volume in the bath in liters (e.g., 20 L from Tambah Proyek / Mulai Pindai).
    var volumeAwalLiter: Double {
        Double(air > 0 ? air : (airResepTersimpan ?? resep?.air ?? 0))
    }

    /// The dye the bath should hold (g/L): the recipe's dye over the recipe water (L).
    var targetPewarnaGramPerLiter: Double {
        guard volumeResepLiter > 0 else { return 0 }
        return pewarna.reduce(0) { $0 + $1.gram } / volumeResepLiter
    }

    /// The dye in the bath now (g/L). The calibration is a = A0 / C_target, so C = A / a is the target times the
    /// absorbance share (`percent` of the initial one) that is left.
    func konsentrasiPewarnaGramPerLiter(kepekatan percent: Double) -> Double {
        targetPewarnaGramPerLiter * max(0, percent) / 100
    }

    /// The dye to add to bring the bath back to its target: (C_target - C_bath) x V, split by ingredient like the
    /// recipe. `volumeLiter` is the bath after the water was added; without a positive one the bath is taken at
    /// `volumeAwalLiter`.
    func pewarnaYangDitambah(kepekatan percent: Double, volumeLiter: Double? = nil) -> [Bahan] {
        var volume = volumeAwalLiter
        if let volumeLiter, volumeLiter > 0 {
            volume = volumeLiter
        }
        let totalGram = max(0, targetPewarnaGramPerLiter - konsentrasiPewarnaGramPerLiter(kepekatan: percent)) * volume
        let totalResep = pewarna.reduce(0) { $0 + $1.gram }
        return pewarna.map { Bahan(kode: $0.kode, gram: totalResep > 0 ? totalGram * $0.gram / totalResep : 0) }
    }

    /// Undoes `selesaikan` when the change could not be saved.
    func batalkanSelesai() {
        kepekatanAkhir = nil
        phAkhir = nil
        status = .aktif
    }
}

extension Bahan {
    /// Grams rounded up to a whole gram, in kg from 1000 grams: "30gr", "1.5kg".
    static func formatBerat(gram: Double) -> String {
        let dibulatkan = gram.rounded(.up)
        guard dibulatkan >= 1000 else { return String(format: "%.0fgr", dibulatkan) }
        return String(format: "%gkg", dibulatkan / 1000)
    }
}

/// Projects split for the Proyek list: active first, both newest on top.
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
