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
    var pewarnaTersimpan: [Bahan]?
    var zatPembantuTersimpan: [Bahan]?
    var airTersimpan: Int?
    var tanggal: Date
    var namaWarna: String
    var warnaHex: String
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

    var air: Int {
        get { airTersimpan ?? resep?.air ?? 0 }
        set { airTersimpan = newValue }
    }

    /// A new, active project. Name, colour, limits and ingredients are copied from `resep`,
    /// so the project stays correct when the recipe is edited or deleted.
    init(nama: String, perangkatNama: String, resep: Resep, jumlahKain: Int, tanggal: Date = .now) {
        id = UUID()
        namaTersimpan = nama
        statusTersimpan = .aktif
        perangkatNamaTersimpan = perangkatNama
        self.tanggal = tanggal
        namaWarna = resep.namaWarna
        warnaHex = resep.warnaHex
        batasKepekatan = resep.kepekatan
        batasPH = resep.batasPH
        pewarnaTersimpan = resep.pewarna
        zatPembantuTersimpan = resep.zatPembantu
        airTersimpan = resep.air
        self.jumlahKain = jumlahKain
        self.resep = resep
    }

    /// Stores the final readings and moves the project to the inactive list. Does nothing when already finished.
    func selesaikan(kepekatanAkhir: Double?, phAkhir: Double?) {
        guard status == .aktif else { return }
        self.kepekatanAkhir = kepekatanAkhir
        self.phAkhir = phAkhir
        status = .nonaktif
    }

    /// The recipe's water for all the cloth, in liters (the recipe grams are per cloth).
    var volumeResepLiter: Double {
        Double(air * jumlahKain) / 1000
    }

    /// The dye the bath should hold (g/L): the recipe's dye for all the cloth over the recipe water.
    var targetPewarnaGramPerLiter: Double {
        guard volumeResepLiter > 0 else { return 0 }
        return pewarna.reduce(0) { $0 + $1.gram } * Double(jumlahKain) / volumeResepLiter
    }

    /// The dye in the bath now (g/L). The calibration is a = A0 / C_target, so C = A / a is the target times the
    /// absorbance share (`percent` of the initial one) that is left.
    func konsentrasiPewarnaGramPerLiter(kepekatan percent: Double) -> Double {
        targetPewarnaGramPerLiter * max(0, percent) / 100
    }

    /// The dye to add to bring the bath back to its target: (C_target - C_bath) x V, split by ingredient like the
    /// recipe. `volumeLiter` is the bath after the water was added; without a positive one the bath is taken at the
    /// recipe volume (no water added).
    func pewarnaYangDitambah(kepekatan percent: Double, volumeLiter: Double? = nil) -> [Bahan] {
        var volume = volumeResepLiter
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

struct ProyekMeasurement: Identifiable, Equatable {
    let id: String
    let title: String
    let value: String
    let isCurrent: Bool
}

struct ProyekColorMeasurements: Equatable {
    private static let unknownValue = "—"

    let colorConcentrationLimit: Double
    let waterPHLimit: Double
    let initial: [ProyekMeasurement]
    let current: [ProyekMeasurement]

    init(colorConcentrationLimit: Double, waterPHLimit: Double, initialWaterPH: Double? = nil) {
        self.init(
            colorConcentrationLimit: colorConcentrationLimit,
            waterPHLimit: waterPHLimit,
            initial: [
                ProyekMeasurement(
                    id: "initial-color-concentration",
                    title: "Kepekatan Warna Awal",
                    value: "100%",
                    isCurrent: false
                ),
                ProyekMeasurement(
                    id: "color-concentration-limit",
                    title: "Batas Kepekatan Warna",
                    value: "\(Self.format(colorConcentrationLimit))%",
                    isCurrent: false
                ),
                ProyekMeasurement(
                    id: "initial-water-ph",
                    title: "pH Air Awal",
                    value: initialWaterPH.map(Self.format) ?? Self.unknownValue,
                    isCurrent: false
                ),
                ProyekMeasurement(
                    id: "water-ph-limit",
                    title: "Batas pH",
                    value: Self.format(waterPHLimit),
                    isCurrent: false
                ),
            ],
            current: [
                ProyekMeasurement(
                    id: "current-color-concentration",
                    title: "Kepekatan Warna Sekarang",
                    value: Self.unknownValue,
                    isCurrent: true
                ),
                ProyekMeasurement(
                    id: "current-water-ph",
                    title: "pH Air Sekarang",
                    value: Self.unknownValue,
                    isCurrent: true
                ),
            ]
        )
    }

    private init(
        colorConcentrationLimit: Double,
        waterPHLimit: Double,
        initial: [ProyekMeasurement],
        current: [ProyekMeasurement]
    ) {
        self.colorConcentrationLimit = colorConcentrationLimit
        self.waterPHLimit = waterPHLimit
        self.initial = initial
        self.current = current
    }

    /// Locale-independent, drops trailing zeros: 7 -> "7", 7.5 -> "7.5".
    static func format(_ value: Double) -> String {
        String(format: "%g", value)
    }

    func withCurrentConcentration(
        _ measurement: ColorMeasurement,
        relativeTo baseline: Double
    ) -> ProyekColorMeasurements {
        var updatedCurrent = current
        guard let index = updatedCurrent.firstIndex(where: { $0.id == "current-color-concentration" }) else {
            return self
        }

        updatedCurrent[index] = ProyekMeasurement(
            id: updatedCurrent[index].id,
            title: updatedCurrent[index].title,
            value: measurement.formattedConcentration(relativeTo: baseline),
            isCurrent: updatedCurrent[index].isCurrent
        )
        return replacingCurrent(updatedCurrent)
    }

    func withCurrentConcentration(percent: Double) -> ProyekColorMeasurements {
        var updatedCurrent = current
        guard let index = updatedCurrent.firstIndex(where: { $0.id == "current-color-concentration" }) else {
            return self
        }

        updatedCurrent[index] = ProyekMeasurement(
            id: updatedCurrent[index].id,
            title: updatedCurrent[index].title,
            value: ColorMeasurement.formatPercent(percent),
            isCurrent: updatedCurrent[index].isCurrent
        )
        return replacingCurrent(updatedCurrent)
    }

    func withCurrentWaterPH(_ waterPH: Double?) -> ProyekColorMeasurements {
        var updatedCurrent = current
        guard let index = updatedCurrent.firstIndex(where: { $0.id == "current-water-ph" }) else {
            return self
        }

        updatedCurrent[index] = ProyekMeasurement(
            id: updatedCurrent[index].id,
            title: updatedCurrent[index].title,
            value: waterPH.map(Self.format) ?? Self.unknownValue,
            isCurrent: updatedCurrent[index].isCurrent
        )
        return replacingCurrent(updatedCurrent)
    }

    /// Clears the current concentration (the baseline it was measured against is gone).
    func withoutCurrentConcentration() -> ProyekColorMeasurements {
        var updatedCurrent = current
        guard let index = updatedCurrent.firstIndex(where: { $0.id == "current-color-concentration" }) else {
            return self
        }

        updatedCurrent[index] = ProyekMeasurement(
            id: updatedCurrent[index].id,
            title: updatedCurrent[index].title,
            value: Self.unknownValue,
            isCurrent: updatedCurrent[index].isCurrent
        )
        return replacingCurrent(updatedCurrent)
    }

    /// Shows `waterPH` as the initial pH, or the unknown value when it is nil.
    func withInitialWaterPH(_ waterPH: Double?) -> ProyekColorMeasurements {
        replacingInitial(id: "initial-water-ph", value: waterPH.map(Self.format) ?? Self.unknownValue)
    }

    /// Shows the initial concentration (always 100%) once the user has set it, the unknown value before.
    func withInitialConcentration(isSet: Bool) -> ProyekColorMeasurements {
        replacingInitial(id: "initial-color-concentration", value: isSet ? "100%" : Self.unknownValue)
    }

    private func replacingInitial(id: String, value: String) -> ProyekColorMeasurements {
        var updatedInitial = initial
        guard let index = updatedInitial.firstIndex(where: { $0.id == id }) else {
            return self
        }

        updatedInitial[index] = ProyekMeasurement(
            id: id,
            title: updatedInitial[index].title,
            value: value,
            isCurrent: updatedInitial[index].isCurrent
        )
        return ProyekColorMeasurements(
            colorConcentrationLimit: colorConcentrationLimit,
            waterPHLimit: waterPHLimit,
            initial: updatedInitial,
            current: current
        )
    }

    private func replacingCurrent(_ current: [ProyekMeasurement]) -> ProyekColorMeasurements {
        ProyekColorMeasurements(
            colorConcentrationLimit: colorConcentrationLimit,
            waterPHLimit: waterPHLimit,
            initial: initial,
            current: current
        )
    }

    func concentration(
        for measurement: ColorMeasurement,
        relativeTo baseline: Double
    ) -> Double? {
        measurement.concentration(relativeTo: baseline)
    }

    var displayedMeasurements: [ProyekMeasurement] {
        guard current.count >= 2, initial.count >= 4 else {
            return initial
        }

        return [
            current[0],
            initial[0],
            initial[1],
            current[1],
            initial[2],
            initial[3],
        ]
    }
}
