import Combine
import Foundation

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

    @Published var latestConcentration: Double?
    @Published private(set) var latestWaterPH: Double?
    @Published private(set) var lastMeasurementAt: Date?

    var repairGuide: PerbaikiLarutanViewModel?

    private let service: any ColorMeasurementSource
    private var measurementTask: Task<Void, Never>?
    var initialVisibleAverage: Double?

    var initialRatios: [Double]?
    private(set) var latestMeasurement: ColorMeasurement?
    var warningTracker = MeasurementWarningTracker()

    @Published private var publishedConnectionState: DeviceConnectionState = .disconnected

    var connectionState: DeviceConnectionState {
        service.connectionState
    }

    private func refreshConnectionState() {
        let current = service.connectionState
        if current != publishedConnectionState {
            publishedConnectionState = current
        }
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

        if proyek.status == .aktif, let baseline = proyek.visibleAverageAwal {
            initialVisibleAverage = baseline
            initialRatios = proyek.rasioAwal
            measurements = makeMeasurements()
            isDataScanned = true
        }
    }

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
            return
        } catch {
            let message = "Gagal membaca data warna dari AS7341: \(error.localizedDescription)"
            colorMeasurementError = message
            print("[Proyek] ❌ \(message)")
        }
    }

    func mulaiPindaiDenganBaselineAwal(in persistence: some ModelPersisting) async {
        clearRepairGuide()
        await mulaiPindai()
        guard colorMeasurementError == nil, !isInitialColorSet else { return }
        _ = tetapkanWarnaAwal(in: persistence)
    }

    func sambungkanUlang(in persistence: some ModelPersisting) async {
        measurementTask?.cancel()
        measurementTask = nil
        await mulaiPindai()
        guard colorMeasurementError == nil else { return }
        if !isInitialColorSet {
            _ = tetapkanWarnaAwal(in: persistence)
        }
    }

    var isConcentrationLow: Bool {
        latestConcentration.map { $0 < measurements.colorConcentrationLimit } ?? false
    }

    var isWaterPHLow: Bool {
        latestWaterPH.map { $0 < measurements.waterPHLimit } ?? false
    }

    var currentIssue: QualityIssue? {
        switch (isConcentrationLow, isWaterPHLow) {
        case (true, true): .keduanya
        case (true, false): .kepekatan
        case (false, true): .phAir
        case (false, false): nil
        }
    }

    func isBelowLimit(_ measurement: ProyekMeasurement) -> Bool {
        switch measurement.id {
        case "current-color-concentration": isConcentrationLow
        case "current-water-ph": isWaterPHLow
        default: false
        }
    }

    func berhenti() {
        measurementTask?.cancel()
        measurementTask = nil
    }

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
            while let self, !Task.isCancelled {
                for await measurement in service.measurementUpdates() {
                    if Task.isCancelled {
                        break
                    }
                    updateCurrentColorMeasurement(measurement)
                }
                if Task.isCancelled { break }
                refreshConnectionState()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    private func updateCurrentColorMeasurement(_ measurement: ColorMeasurement) {
        latestMeasurement = measurement
        lastMeasurementAt = .now
        refreshConnectionState()
        var updated = measurements
        if let waterPH = measurement.waterPH {
            updated = updated.withCurrentWaterPH(waterPH)
            latestWaterPH = waterPH
        }

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

        if let currentIssue {
            let issue = qualityAlert?.issue.combining(with: currentIssue) ?? currentIssue
            if issue != qualityAlert?.issue, qualityAlert != nil || startsNewDip {
                qualityAlert = makeQualityAlert(for: issue)
            }
        }
    }

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
