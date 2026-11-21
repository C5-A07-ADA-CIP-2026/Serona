//
//  ProyekDetailViewModel+AwalSetup.swift
//  Serona
//

import Foundation

// MARK: Initial color and pH

extension ProyekDetailViewModel {
    /// True once the user has set the initial pH from a live reading.
    var isInitialPHSet: Bool {
        proyek.phAwal != nil
    }

    /// True while a live pH reading can be set as the initial pH of this scanned, active project.
    var canSetInitialPH: Bool {
        proyek.status == .aktif && isDataScanned && !isInitialPHSet && latestWaterPH != nil
    }

    /// Sets the latest live pH reading as the initial pH and saves it. The sensor never sets it by itself.
    /// Returns `false` and changes nothing when there is no reading to set, it is already set, or the save fails.
    @discardableResult
    func tetapkanPHAwal(in persistence: some ModelPersisting) -> Bool {
        guard canSetInitialPH, let waterPH = latestWaterPH else { return false }
        return savePHAwal(waterPH, in: persistence)
    }

    /// Clears the initial pH so a new one can be set from the live reading.
    /// Returns `false` and keeps the previous value when it was not set or the save fails.
    @discardableResult
    func ukurUlangPHAwal(in persistence: some ModelPersisting) -> Bool {
        guard proyek.status == .aktif, isDataScanned, isInitialPHSet else { return false }
        return savePHAwal(nil, in: persistence)
    }

    private func savePHAwal(_ waterPH: Double?, in persistence: some ModelPersisting) -> Bool {
        let sebelumnya = proyek.phAwal
        proyek.phAwal = waterPH
        guard save(persistence, undo: { proyek.phAwal = sebelumnya }) else { return false }
        measurements = measurements.withInitialWaterPH(waterPH)
        return true
    }

    /// True once the user has set the initial color (the 100% baseline) from a live reading.
    var isInitialColorSet: Bool {
        proyek.visibleAverageAwal != nil
    }

    /// True while a live reading can be set as the initial color of this scanned, active project.
    var canSetInitialColor: Bool {
        proyek.status == .aktif && isDataScanned && !isInitialColorSet && (latestMeasurement?.visibleAverage ?? 0) > 0
    }

    /// Sets the latest live reading as the initial color (100%) and saves it. The sensor never sets it by itself.
    /// Returns `false` and changes nothing when there is no reading to set, it is already set, or the save fails.
    @discardableResult
    func tetapkanWarnaAwal(in persistence: some ModelPersisting) -> Bool {
        guard canSetInitialColor, let latest = latestMeasurement else { return false }
        let sebelumnya = proyek.visibleAverageAwal
        let rasioSebelumnya = proyek.rasioAwal
        proyek.visibleAverageAwal = latest.visibleAverage
        proyek.rasioAwal = latest.channelRatios
        guard save(persistence, undo: {
            proyek.visibleAverageAwal = sebelumnya
            proyek.rasioAwal = rasioSebelumnya
        }) else { return false }

        initialVisibleAverage = latest.visibleAverage
        initialRatios = latest.channelRatios
        warningTracker.reset()
        latestConcentration = 100
        measurements = measurements
            .withInitialConcentration(isSet: true)
            .withCurrentConcentration(percent: 100)
        return true
    }

    /// Clears the initial color and the concentration measured against it, so a new one can be set.
    /// Returns `false` and keeps the previous value when it was not set or the save fails.
    @discardableResult
    func ukurUlangWarnaAwal(in persistence: some ModelPersisting) -> Bool {
        guard proyek.status == .aktif, isDataScanned, isInitialColorSet else { return false }
        let sebelumnya = proyek.visibleAverageAwal
        let rasioSebelumnya = proyek.rasioAwal
        proyek.visibleAverageAwal = nil
        proyek.rasioAwal = nil
        guard save(persistence, undo: {
            proyek.visibleAverageAwal = sebelumnya
            proyek.rasioAwal = rasioSebelumnya
        }) else { return false }

        initialVisibleAverage = nil
        initialRatios = nil
        warningTracker.reset()
        latestConcentration = nil
        colorConcentrationWarning = nil
        measurements = measurements
            .withInitialConcentration(isSet: false)
            .withoutCurrentConcentration()
        return true
    }

    /// Saves; on failure runs `undo` and reports the error.
    func save(_ persistence: some ModelPersisting, undo: () -> Void) -> Bool {
        do {
            try persistence.save()
            return true
        } catch {
            undo()
            saveError = "Gagal menyimpan proyek: \(error.localizedDescription)"
            return false
        }
    }
}
