//
//  ProyekDetailViewModel+AirBersih.swift
//  Serona
//

import Foundation

/// The clean-water reading the absorbance of the bath is measured against, and the dye amount that follows from it.
extension ProyekDetailViewModel {
    /// True once the user has set the clean-water reading the absorbance is measured against.
    var isCleanWaterSet: Bool {
        proyek.rasioAirBersih != nil
    }

    /// True while a live reading with channels can be set as the clean water of this scanned, active project.
    var canSetCleanWater: Bool {
        proyek.status == .aktif && isDataScanned && !isCleanWaterSet && latestMeasurement?.channelRatios != nil
    }

    /// Sets the channel ratios of the latest live reading (the probe in clean water) and saves them.
    /// Returns `false` and changes nothing when there is nothing to set, it is already set, or the save fails.
    @discardableResult
    func tetapkanAirBersih(in persistence: some ModelPersisting) -> Bool {
        guard canSetCleanWater, let ratios = latestMeasurement?.channelRatios else { return false }
        return saveAirBersih(ratios, in: persistence)
    }

    /// Clears the clean water so a new one can be set. Until then the concentration uses the baseline-only formula.
    /// Returns `false` and keeps the previous value when it was not set or the save fails.
    @discardableResult
    func ukurUlangAirBersih(in persistence: some ModelPersisting) -> Bool {
        guard proyek.status == .aktif, isDataScanned, isCleanWaterSet else { return false }
        return saveAirBersih(nil, in: persistence)
    }

    private func saveAirBersih(_ ratios: [Double]?, in persistence: some ModelPersisting) -> Bool {
        let sebelumnya = proyek.rasioAirBersih
        proyek.rasioAirBersih = ratios
        return save(persistence, undo: { proyek.rasioAirBersih = sebelumnya })
    }

    /// The dye to add, per ingredient, to bring the concentration back to 100%, with no water added.
    var penambahanPewarna: [Bahan]? {
        penambahanPewarna(volumeLiter: nil)
    }

    /// The dye to add, per ingredient, for a bath of `volumeLiter` (after the water was added). Nil unless the
    /// concentration is absorbance-based (baseline and clean water set), since the amount means nothing for the
    /// older formula.
    func penambahanPewarna(volumeLiter: Double?) -> [Bahan]? {
        guard proyek.rasioAwal != nil, proyek.rasioAirBersih != nil, let latestConcentration else { return nil }
        return proyek.pewarnaYangDitambah(kepekatan: latestConcentration, volumeLiter: volumeLiter)
    }
}
