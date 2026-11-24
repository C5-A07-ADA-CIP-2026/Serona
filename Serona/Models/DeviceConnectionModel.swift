import Foundation

struct ColorMeasurement: Equatable, Decodable, Sendable {
    let visibleAverage: Double
    let clear: UInt16
    let nir: UInt16
    let waterPH: Double?

    let channels: [UInt16]?

    let clearFirst: UInt16?

    init(
        visibleAverage: Double,
        clear: UInt16,
        nir: UInt16,
        waterPH: Double? = nil,
        channels: [UInt16]? = nil,
        clearFirst: UInt16? = nil
    ) {
        self.visibleAverage = visibleAverage
        self.clear = clear
        self.nir = nir
        self.waterPH = waterPH
        self.channels = channels
        self.clearFirst = clearFirst
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        visibleAverage = try container.decodeIfPresent(Double.self, forKey: .visibleAverage)
            ?? container.decode(Double.self, forKey: .concentrationPercent)
        clear = try container.decode(UInt16.self, forKey: .clear)
        nir = try container.decode(UInt16.self, forKey: .nir)
        waterPH = try container.decodeIfPresent(Double.self, forKey: .waterPH)
        channels = try container.decodeIfPresent([UInt16].self, forKey: .channels)
        clearFirst = try container.decodeIfPresent(UInt16.self, forKey: .clearFirst)
    }

    var channelRatios: [Double]? {
        guard let channels, channels.count == 8, let clearFirst, clearFirst > 0, clear > 0 else { return nil }
        return channels.enumerated().map { index, count in
            Double(count) / Double(index < 4 ? clearFirst : clear)
        }
    }

    func concentration(relativeToRatios baseline: [Double]) -> Double? {
        guard let ratios = channelRatios, baseline.count == ratios.count else { return nil }
        let transmittances = zip(ratios, baseline).compactMap { ratio, base in
            base > 0 ? ratio / base : nil
        }
        return transmittances.min().map { $0 * 100 }
    }

    private static let transmittanceSpreadLimit = 0.08

    static func absorbance(ratios: [Double], cleanRatios: [Double]) -> Double? {
        guard ratios.count == cleanRatios.count else { return nil }
        let transmittances = zip(ratios, cleanRatios).compactMap { ratio, clean -> Double? in
            guard clean > 0 else { return 1 }
            return ratio > 0 ? ratio / clean : nil
        }
        guard let lowest = transmittances.min(), let highest = transmittances.max() else { return nil }
        let rawEffective = highest - lowest < transmittanceSpreadLimit
            ? transmittances.reduce(0, +) / Double(transmittances.count)
            : lowest

        let effective = min(1.0, rawEffective)
        return -log10(effective)
    }

    func concentration(relativeToRatios baseline: [Double], cleanRatios: [Double]) -> Double? {
        guard let ratios = channelRatios,
              let current = Self.absorbance(ratios: ratios, cleanRatios: cleanRatios),
              let initial = Self.absorbance(ratios: baseline, cleanRatios: cleanRatios),
              initial > 0
        else { return nil }
        return max(0, current / initial * 100)
    }

    func concentration(relativeTo baseline: Double) -> Double? {
        guard baseline > 0 else { return nil }
        return (visibleAverage / baseline) * 100
    }

    func formattedConcentration(relativeTo baseline: Double) -> String {
        guard let percentage = concentration(relativeTo: baseline) else { return "0.0%" }
        return Self.formatPercent(percentage)
    }

    static func formatPercent(_ percentage: Double) -> String {
        String(
            format: "%.1f%%",
            locale: Locale(identifier: "en_US_POSIX"),
            percentage
        )
    }

    private enum CodingKeys: String, CodingKey {
        case visibleAverage
        case concentrationPercent
        case clear
        case nir
        case waterPH = "ph"
        case channels
        case clearFirst = "clear1"
    }
}

extension ColorMeasurement {
    static let defaultCleanWater = ColorMeasurement(
        visibleAverage: 1572.3,
        clear: 7266,
        nir: 248,
        channels: [241, 1305, 2502, 1578, 1913, 2164, 1883, 992],
        clearFirst: 7266
    )

    static let defaultCleanWaterRatios: [Double] = defaultCleanWater.channelRatios ?? Array(repeating: 1.0, count: 8)
}

struct DiscoveredDevice: Identifiable, Hashable, Sendable {
    static let unnamed = "Tanpa Nama"

    let id: UUID
    let nama: String

    nonisolated static func resolveName(peripheralName: String?, advertisedName: String?) -> String? {
        [advertisedName, peripheralName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }
}

protocol DeviceConnecting: Sendable {
    func scanDevices() -> AsyncThrowingStream<DiscoveredDevice, any Error>

    func connect(to device: DiscoveredDevice) async throws

    func disconnect(from device: DiscoveredDevice) async
}

protocol ColorMeasurementSource: Sendable {
    func readInitialColorMeasurement() async throws -> ColorMeasurement
    func measurementUpdates() -> AsyncStream<ColorMeasurement>
    var connectionState: DeviceConnectionState { get }
}

extension ColorMeasurementSource {
    var connectionState: DeviceConnectionState {
        .ready
    }
}

enum DeviceConnectionState: Equatable, Sendable {
    case disconnected
    case connecting
    case discovering
    case ready
    case reconnecting
    case failed(String)
}

protocol DeviceMeasurementProviding: Sendable {
    func measurementSource(for deviceID: UUID) -> any ColorMeasurementSource
}

protocol DeviceConnectionService: DeviceConnecting, DeviceMeasurementProviding, Sendable {}

struct SimulatedDeviceConnectionService: DeviceConnectionService, ColorMeasurementSource {
    static let devices = ["A", "B", "C", "D", "E", "F"].enumerated().map { index, letter in
        DiscoveredDevice(
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000000E\(index + 1)")!,
            nama: "ESP 32 - \(letter)"
        )
    }

    let discoveryDelay: Duration
    let connectionDelay: Duration

    init(
        discoveryDelay: Duration = .seconds(1),
        connectionDelay: Duration = .seconds(2)
    ) {
        self.discoveryDelay = discoveryDelay
        self.connectionDelay = connectionDelay
    }

    func scanDevices() -> AsyncThrowingStream<DiscoveredDevice, any Error> {
        let delay = discoveryDelay
        return AsyncThrowingStream { continuation in
            let task = Task {
                print("[Simulator] 🔍 Mensimulasikan pencarian perangkat ESP32...")
                for device in Self.devices {
                    try? await Task.sleep(for: delay)
                    if Task.isCancelled {
                        break
                    }
                    continuation.yield(device)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func connect(to device: DiscoveredDevice) async throws {
        print("[Simulator] ⏳ Mensimulasikan koneksi ke \(device.nama)...")
        try await Task.sleep(for: connectionDelay)
        print("[Simulator] ✅ Perangkat simulasi \(device.nama) terhubung.")
    }

    func disconnect(from device: DiscoveredDevice) async {
        print("[Simulator] 🔌 Perangkat simulasi \(device.nama) diputus.")
    }

    func measurementSource(for _: UUID) -> any ColorMeasurementSource {
        self
    }

    func readInitialColorMeasurement() async throws -> ColorMeasurement {
        ColorMeasurement(visibleAverage: 100, clear: 1000, nir: 100)
    }

    func measurementUpdates() -> AsyncStream<ColorMeasurement> {
        AsyncStream { continuation in
            continuation.yield(ColorMeasurement(visibleAverage: 100, clear: 1000, nir: 100))
        }
    }
}
