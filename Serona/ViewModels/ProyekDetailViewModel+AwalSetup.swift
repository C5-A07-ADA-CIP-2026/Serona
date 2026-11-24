import Foundation

extension ProyekDetailViewModel {
    var isInitialPHSet: Bool {
        proyek.phAwal != nil
    }

    var canSetInitialPH: Bool {
        proyek.status == .aktif && isDataScanned && !isInitialPHSet && latestWaterPH != nil
    }

    @discardableResult
    func tetapkanPHAwal(in persistence: some ModelPersisting) -> Bool {
        guard canSetInitialPH, let waterPH = latestWaterPH else { return false }
        return savePHAwal(waterPH, in: persistence)
    }

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

    var isInitialColorSet: Bool {
        proyek.visibleAverageAwal != nil
    }

    var canSetInitialColor: Bool {
        proyek.status == .aktif && isDataScanned && !isInitialColorSet && (latestMeasurement?.visibleAverage ?? 0) > 0
    }

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
