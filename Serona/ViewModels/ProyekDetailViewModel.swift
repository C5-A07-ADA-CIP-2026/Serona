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

    @Published var measurements: ProyekColorMeasurements
    @Published private(set) var isDataScanned = false
    @Published private(set) var isScanning = false
    @Published private(set) var colorMeasurementError: String?
    @Published var colorConcentrationWarning: String?
    @Published private(set) var waterPHWarning: String?
    @Published private(set) var qualityAlert: QualityAlert?
    @Published var saveError: String?

    /// Latest streamed readings (concentration in percent of the baseline), kept for finishing the project.
    @Published var latestConcentration: Double?
    @Published private(set) var latestWaterPH: Double?
    @Published private(set) var lastMeasurementAt: Date?

    /// Preserves step progress (`Tahap 1`, `Tahap 2`, `Tahap 3`) if the user closes and reopens the repair modal.
    var repairGuide: PerbaikiLarutanViewModel?

    private let service: any ColorMeasurementSource
    private var measurementTask: Task<Void, Never>?
    var initialVisibleAverage: Double?
    /// The channel / clear ratios of the initial color; the concentration is measured against these when the
    /// readings carry channels, else against `initialVisibleAverage`.
    var initialRatios: [Double]?
    private(set) var latestMeasurement: ColorMeasurement?
    var warningTracker = MeasurementWarningTracker()

    var connectionState: DeviceConnectionState {
        service.connectionState
    }

    func isMeasurementStale(at date: Date = .now) -> Bool {
        guard let lastMeasurementAt else { return true }
        return date.timeIntervalSince(lastMeasurementAt) > 3
    }

    init(proyek: Proyek, service: (any ColorMeasurementSource)? = nil) {
        self.proyek = proyek
        self.service = service ?? proyek.perangkatID.map {
            DeviceConnectionServices.default.measurementSource(for: $0)
        } ?? MissingMeasurementSource()
        measurements = ProyekColorMeasurements(
            colorConcentrationLimit: proyek.batasKepekatan,
            waterPHLimit: proyek.batasPH
        )
        // A project whose initial color was already set is picked up where it was left.
        if proyek.status == .aktif, let baseline = proyek.visibleAverageAwal {
            initialVisibleAverage = baseline
            initialRatios = proyek.rasioAwal
            measurements = makeMeasurements()
            isDataScanned = true
        }
    }

    /// Returns the ongoing repair guide for this bak so reopening the sheet resumes at the last step,
    /// or creates a new one if no repair is currently in progress.
    func repairGuide(for issue: QualityIssue) -> PerbaikiLarutanViewModel {
        if let existing = repairGuide, !existing.isFinished {
            existing.updateIssue(issue)
            return existing
        }
        let guide = PerbaikiLarutanViewModel(
            issue: issue,
            proyek: proyek,
            pHSebelum: latestWaterPH
        )
        repairGuide = guide
        return guide
    }

    func clearRepairGuide() {
        repairGuide = nil
    }

    /// Connects to the device and starts streaming live readings. The initial color and pH are not taken from
    /// this read: the user sets them from the live readings (`tetapkanWarnaAwal`, `tetapkanPHAwal`).
    /// Does nothing for a finished project or while a scan is already reading the device.
    func mulaiPindai() async {
        print("[Proyek] ▶️ mulaiPindai \(proyek.nama) status=\(proyek.status) isScanning=\(isScanning)")
        guard proyek.status == .aktif, !isScanning else {
            print("[Proyek] ⛔️ ditolak guard")
            return
        }
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

    /// Starts a newly configured bath and persists its first successful color reading as the 100% baseline.
    /// Reconnection must use `sambungkanUlang(in:)` or `lanjutkanPengukuran()` so the saved baseline is preserved.
    func mulaiPindaiDenganBaselineAwal(in persistence: some ModelPersisting) async {
        clearRepairGuide()
        await mulaiPindai()
        guard colorMeasurementError == nil, !isInitialColorSet else { return }
        _ = tetapkanWarnaAwal(in: persistence)
    }

    /// Reconnects an active bath after its IoT sensor disconnected, retrieving and keeping the saved `Proyek` data.
    func sambungkanUlang(in persistence: some ModelPersisting) async {
        measurementTask?.cancel()
        measurementTask = nil
        await mulaiPindai()
        guard colorMeasurementError == nil else { return }
        if !isInitialColorSet {
            _ = tetapkanWarnaAwal(in: persistence)
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
        print("[Proyek] ✅ beginMeasuring \(proyek.nama)")
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
        lastMeasurementAt = .now
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
        return measurement.concentration(
            relativeToRatios: initialRatios,
            cleanRatios: Self.defaultCleanWaterRatios
        ) ?? measurement.concentration(relativeToRatios: initialRatios)
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

    /// Finishes the active bath: clears all saved bath data and resets the bak to unused (`nonaktif`).
    @discardableResult
    func selesaikan(in persistence: some ModelPersisting) -> Bool {
        guard proyek.status == .aktif else { return false }

        let savedName = proyek.namaWarna
        let savedHex = proyek.warnaHex
        let savedDeviceName = proyek.perangkatNama
        let savedDeviceID = proyek.perangkatID
        let savedPewarna = proyek.pewarna
        let savedZat = proyek.zatPembantu
        let savedAir = proyek.airTersimpan
        let savedAirResep = proyek.airResepTersimpan
        let savedResep = proyek.resep
        let savedBaseline = proyek.visibleAverageAwal
        let savedRasio = proyek.rasioAwal
        let savedAirBersih = proyek.rasioAirBersih
        let savedPHAwal = proyek.phAwal

        proyek.selesaikan()
        do {
            try persistence.save()
        } catch {
            proyek.batalkanSelesai()
            proyek.namaWarna = savedName
            proyek.warnaHex = savedHex
            proyek.perangkatNama = savedDeviceName
            proyek.perangkatID = savedDeviceID
            proyek.pewarna = savedPewarna
            proyek.zatPembantu = savedZat
            proyek.airTersimpan = savedAir
            proyek.airResepTersimpan = savedAirResep
            proyek.resep = savedResep
            proyek.visibleAverageAwal = savedBaseline
            proyek.rasioAwal = savedRasio
            proyek.rasioAirBersih = savedAirBersih
            proyek.phAwal = savedPHAwal
            saveError = "Gagal menyimpan proyek: \(error.localizedDescription)"
            return false
        }
        clearRepairGuide()
        berhenti()
        return true
    }

    /// Points the active bath at `device` after reconnecting to another sensor, keeping all saved bath data.
    @discardableResult
    func gantiPerangkat(_ device: DiscoveredDevice, in persistence: some ModelPersisting) -> Bool {
        guard proyek.status == .aktif else { return false }

        let sebelumnya = proyek.perangkatNama
        let idSebelumnya = proyek.perangkatID
        proyek.perangkatNama = device.nama
        proyek.perangkatID = device.id
        do {
            try persistence.save()
        } catch {
            proyek.perangkatNama = sebelumnya
            proyek.perangkatID = idSebelumnya
            saveError = "Gagal menyimpan proyek: \(error.localizedDescription)"
            return false
        }
        return true
    }

    /// Switches the project to `device` (see `gantiPerangkat`) and reconnects with saved bath data intact.
    @discardableResult
    func pindahPerangkat(_ device: DiscoveredDevice, in persistence: some ModelPersisting) async -> Bool {
        guard gantiPerangkat(device, in: persistence) else { return false }
        await sambungkanUlang(in: persistence)
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
            colorConcentrationLimit: proyek.batasKepekatan,
            waterPHLimit: proyek.batasPH,
            initialWaterPH: proyek.phAwal
        )
        .withInitialConcentration(isSet: proyek.visibleAverageAwal != nil)
    }
}

private struct MissingMeasurementSource: ColorMeasurementSource {
    var connectionState: DeviceConnectionState {
        .disconnected
    }

    func readInitialColorMeasurement() async throws -> ColorMeasurement {
        throw NSError(
            domain: "BLEService",
            code: 404,
            userInfo: [NSLocalizedDescriptionKey: "Pilih kembali perangkat untuk bak ini"]
        )
    }

    func measurementUpdates() -> AsyncStream<ColorMeasurement> {
        AsyncStream { $0.finish() }
    }
}
