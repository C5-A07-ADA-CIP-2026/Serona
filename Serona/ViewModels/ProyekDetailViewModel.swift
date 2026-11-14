//
//  ProyekDetailViewModel.swift
//  Serona
//

import Combine
import Foundation

/// Scans the color of one project and finishes it. The limits come from the project, not from the recipe it copied.
@MainActor
final class ProyekDetailViewModel: ObservableObject {
    static let defaultConcentrationLimit: Double = 90
    static let defaultWaterPHLimit: Double = 11
    
    let proyek: Proyek

    @Published private(set) var measurements: ProyekColorMeasurements
    @Published private(set) var isDataScanned = false
    @Published private(set) var isScanning = false
    @Published private(set) var colorMeasurementError: String?
    @Published private(set) var colorConcentrationWarning: String?
    @Published private(set) var waterPHWarning: String?
    @Published private(set) var qualityAlert: QualityAlert?
    @Published private(set) var saveError: String?

    /// Latest streamed readings (concentration in percent of the baseline), kept for finishing the project.
    @Published private(set) var latestConcentration: Double?
    @Published private(set) var latestWaterPH: Double?

    private let service: any ColorMeasurementSource
    private var measurementTask: Task<Void, Never>?
    private var initialVisibleAverage: Double?
    /// The channel / clear ratios of the initial color; the concentration is measured against these when the
    /// readings carry channels, else against `initialVisibleAverage`.
    private var initialRatios: [Double]?
    private(set) var latestMeasurement: ColorMeasurement?
    private var warningTracker = MeasurementWarningTracker()

    init(proyek: Proyek, service: (any ColorMeasurementSource)? = nil) {
        self.proyek = proyek
        self.service = service ?? DeviceConnectionServices.default
        measurements = ProyekColorMeasurements(
            colorConcentrationLimit: Self.defaultConcentrationLimit,
            waterPHLimit: Self.defaultWaterPHLimit
        )
        // A project whose initial color was already set is picked up where it was left.
        if proyek.status == .aktif, let baseline = proyek.visibleAverageAwal {
            initialVisibleAverage = baseline
            initialRatios = proyek.rasioAwal
            measurements = makeMeasurements()
            isDataScanned = true
        }
    }

    /// Connects to the device and starts streaming live readings. The initial color and pH are not taken from
    /// this read: the user sets them from the live readings (`tetapkanWarnaAwal`, `tetapkanPHAwal`).
    /// Does nothing for a finished project or while a scan is already reading the device.
    func mulaiPindai() async {
        guard proyek.status == .aktif, !isScanning else { return }
        isScanning = true
        defer { isScanning = false }
        colorMeasurementError = nil
        do {
            let initial = try await service.readInitialColorMeasurement()
            beginMeasuring(from: initial)
        } catch is CancellationError {
            // A cancelled read is not a failure.
            return
        } catch {
            let message = "Gagal membaca data warna dari AS7341: \(error.localizedDescription)"
            colorMeasurementError = message
            print("[Proyek] ❌ \(message)")
        }
    }

    /// True while the latest concentration is below the project limit.
    var isConcentrationLow: Bool {
        latestConcentration.map { $0 < measurements.colorConcentrationLimit } ?? false
    }

    /// True while the latest water pH is below the project limit.
    var isWaterPHLow: Bool {
        latestWaterPH.map { $0 < measurements.waterPHLimit } ?? false
    }

    /// What is below its limit right now; nil while both readings are within their limits.
    var currentIssue: QualityIssue? {
        switch (isConcentrationLow, isWaterPHLow) {
        case (true, true): .keduanya
        case (true, false): .kepekatan
        case (false, true): .phAir
        case (false, false): nil
        }
    }

    /// True for the "current" row whose reading is below its limit.
    func isBelowLimit(_ measurement: ProyekMeasurement) -> Bool {
        switch measurement.id {
        case "current-color-concentration": isConcentrationLow
        case "current-water-ph": isWaterPHLow
        default: false
        }
    }

    /// Ends the live stream (when leaving the screen or finishing).
    func berhenti() {
        measurementTask?.cancel()
        measurementTask = nil
    }

    /// Resumes the live stream of a project whose scan was started earlier, using the saved baseline.
    /// Does nothing for an unscanned or finished project, or when the stream is already running.
    func lanjutkanPengukuran() {
        guard proyek.status == .aktif, isDataScanned, measurementTask == nil else { return }
        startStreaming()
    }

    private func beginMeasuring(from initial: ColorMeasurement) {
        initialVisibleAverage = proyek.visibleAverageAwal
        initialRatios = proyek.rasioAwal
        latestMeasurement = initial
        warningTracker.reset()
        measurements = makeMeasurements()
        isDataScanned = true
        updateCurrentColorMeasurement(initial)
        startStreaming()
    }

    private func startStreaming() {
        measurementTask?.cancel()
        measurementTask = Task { [weak self] in
            guard let self else { return }
            for await measurement in service.measurementUpdates() {
                // A reading buffered before `berhenti()` must not be applied afterwards.
                if Task.isCancelled {
                    break
                }
                updateCurrentColorMeasurement(measurement)
            }
        }
    }

    private func updateCurrentColorMeasurement(_ measurement: ColorMeasurement) {
        latestMeasurement = measurement
        var updated = measurements
        if let waterPH = measurement.waterPH {
            updated = updated.withCurrentWaterPH(waterPH)
            latestWaterPH = waterPH
        }

        // The concentration is only known once the user has set the initial color to compare with.
        var concentration: Double?
        if let percent = concentrationPercent(of: measurement) {
            updated = updated.withCurrentConcentration(percent: percent)
            concentration = percent
        } else if let baseline = initialVisibleAverage, baseline > 0 {
            updated = updated.withCurrentConcentration(measurement, relativeTo: baseline)
            concentration = measurement.concentration(relativeTo: baseline)
        } else if measurement.visibleAverage > 0 {
            updated = updated.withCurrentConcentration(percent: measurement.visibleAverage)
            concentration = measurement.visibleAverage
        }
        measurements = updated

        var startsNewDip = false
        if let concentration {
            latestConcentration = concentration
            let limit = updated.colorConcentrationLimit
            if let warning = warningTracker.concentrationWarning(for: concentration, limit: limit) {
                colorConcentrationWarning = warning
                startsNewDip = true
            }
        }

        if let waterPH = measurement.waterPH {
            let warning = MeasurementWarningTracker.waterPHWarning(for: waterPH, limit: updated.waterPHLimit)
            startsNewDip = startsNewDip || (warning != nil && waterPHWarning == nil)
            waterPHWarning = warning
        }

        // The sheet shows once per dip; a new low merges into the alert that is already up.
        if let currentIssue {
            let issue = qualityAlert?.issue.combining(with: currentIssue) ?? currentIssue
            if issue != qualityAlert?.issue, qualityAlert != nil || startsNewDip {
                qualityAlert = makeQualityAlert(for: issue)
            }
        }
    }

    /// Absorbance against the baseline when the clean water is set too, else the lowest channel against the baseline.
    /// Nil without a channel baseline or channels in the reading.
    private func concentrationPercent(of measurement: ColorMeasurement) -> Double? {
        guard let initialRatios else { return nil }
        let absorbanceBased = proyek.rasioAirBersih.flatMap {
            measurement.concentration(relativeToRatios: initialRatios, cleanRatios: $0)
        }
        return absorbanceBased ?? measurement.concentration(relativeToRatios: initialRatios)
    }

    private func makeQualityAlert(for issue: QualityIssue) -> QualityAlert {
        let message = switch issue {
        case .keduanya:
            MeasurementWarningTracker.bothMessage
        case .kepekatan:
            MeasurementWarningTracker.concentrationMessage(limit: measurements.colorConcentrationLimit)
        case .phAir:
            MeasurementWarningTracker.waterPHMessage(limit: measurements.waterPHLimit)
        }
        return QualityAlert(issue: issue, message: message)
    }

    /// Finishes the scanned project: stores the final readings and moves it to the inactive list.
    /// Returns `false` and changes nothing when the project is not active, was not scanned yet, or the save fails.
    /// Final readings are nil (never 0) when the sensor has not streamed them yet.
    @discardableResult
    func selesaikan(in persistence: some ModelPersisting) -> Bool {
        guard proyek.status == .aktif, isDataScanned else { return false }

        proyek.selesaikan(kepekatanAkhir: latestConcentration, phAkhir: latestWaterPH)
        do {
            try persistence.save()
        } catch {
            proyek.batalkanSelesai()
            saveError = "Gagal menyimpan proyek: \(error.localizedDescription)"
            return false
        }
        berhenti()
        return true
    }

    /// Points the project at `device` after the user reconnects to another one because the connection failed.
    /// Returns `false` and keeps the previous device when the project is finished, already being measured
    /// (the device cannot change mid-project) or the save fails.
    @discardableResult
    func gantiPerangkat(_ device: DiscoveredDevice, in persistence: some ModelPersisting) -> Bool {
        guard proyek.status == .aktif, !isDataScanned else { return false }

        let sebelumnya = proyek.perangkatNama
        proyek.perangkatNama = device.nama
        do {
            try persistence.save()
        } catch {
            proyek.perangkatNama = sebelumnya
            saveError = "Gagal menyimpan proyek: \(error.localizedDescription)"
            return false
        }
        return true
    }

    /// Switches the project to `device` (see `gantiPerangkat`) and retries the read that failed, now from the new one.
    @discardableResult
    func pindahPerangkat(_ device: DiscoveredDevice, in persistence: some ModelPersisting) async -> Bool {
        guard gantiPerangkat(device, in: persistence) else { return false }
        await mulaiPindai()
        return true
    }

    func clearSaveError() {
        guard saveError != nil else { return }
        saveError = nil
    }

    func clearColorMeasurementError() {
        guard colorMeasurementError != nil else { return }
        colorMeasurementError = nil
    }

    func clearColorConcentrationWarning() {
        guard colorConcentrationWarning != nil else { return }
        colorConcentrationWarning = nil
    }

    /// Shows the alert again for whatever is below its limit right now (the user dismissed it earlier).
    func tampilkanQualityAlert() {
        guard let currentIssue else { return }
        qualityAlert = makeQualityAlert(for: currentIssue)
    }

    func clearQualityAlert() {
        guard qualityAlert != nil else { return }
        qualityAlert = nil
    }

    func clearWaterPHWarning() {
        guard waterPHWarning != nil else { return }
        waterPHWarning = nil
    }
    
    private func makeMeasurements() -> ProyekColorMeasurements {
        ProyekColorMeasurements(
            colorConcentrationLimit: Self.defaultConcentrationLimit,
            waterPHLimit: Self.defaultWaterPHLimit,
            initialWaterPH: proyek.phAwal
        )
        .withInitialConcentration(isSet: proyek.visibleAverageAwal != nil)
    }
}

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

    /// The rows for the project's saved initial values; those not set yet show as unknown.
//    private func makeMeasurements() -> ProyekColorMeasurements {
//        ProyekColorMeasurements(
//            colorConcentrationLimit: proyek.batasKepekatan,
//            waterPHLimit: proyek.batasPH,
//            initialWaterPH: proyek.phAwal
//        )
//        .withInitialConcentration(isSet: proyek.visibleAverageAwal != nil)
//    }
}
