//
//  DeviceConnectionModel.swift
//  Serona
//

import Foundation

struct ColorMeasurement: Equatable, Decodable, Sendable {
    let visibleAverage: Double
    let clear: UInt16
    let nir: UInt16
    let waterPH: Double?
    /// Raw F1...F8 counts; nil from firmware that does not send them.
    let channels: [UInt16]?
    /// Clear read together with F1-F4 (`clear` is the one read with F5-F8); nil when not sent.
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

    /// Each of F1...F8 divided by the clear of the cycle that read it (F1-F4 by `clearFirst`, F5-F8 by `clear`).
    /// Dividing by clear cancels fluctuations of the LED and distance. Nil without 8 channels or a positive clear.
    var channelRatios: [Double]? {
        guard let channels, channels.count == 8, let clearFirst, clearFirst > 0, clear > 0 else { return nil }
        return channels.enumerated().map { index, count in
            Double(count) / Double(index < 4 ? clearFirst : clear)
        }
    }

    /// Percentage of the baseline in the channel that absorbs the most: the lowest `ratio / baseline` of
    /// the 8 channels. Channels without baseline signal are skipped. Nil without channel data to compare.
    func concentration(relativeToRatios baseline: [Double]) -> Double? {
        guard let ratios = channelRatios, baseline.count == ratios.count else { return nil }
        let transmittances = zip(ratios, baseline).compactMap { ratio, base in
            base > 0 ? ratio / base : nil
        }
        return transmittances.min().map { $0 * 100 }
    }

    /// Channels whose transmittances differ by less than this are read as one color, so they are averaged.
    private static let transmittanceSpreadLimit = 0.08

    /// A = -log10(T) of a bath, with T = ratio / clean-water ratio per channel. T is the mean of the channels
    /// when they differ by less than `transmittanceSpreadLimit`, else the lowest (the dominant color).
    /// A channel with no clean-water signal counts as T = 1; one with no signal in the bath is skipped.
    /// Nil when no channel is left, or the sizes differ.
    static func absorbance(ratios: [Double], cleanRatios: [Double]) -> Double? {
        guard ratios.count == cleanRatios.count else { return nil }
        let transmittances = zip(ratios, cleanRatios).compactMap { ratio, clean -> Double? in
            guard clean > 0 else { return 1 }
            return ratio > 0 ? ratio / clean : nil
        }
        guard let lowest = transmittances.min(), let highest = transmittances.max() else { return nil }
        let effective = highest - lowest < transmittanceSpreadLimit
            ? transmittances.reduce(0, +) / Double(transmittances.count)
            : lowest
        return -log10(effective)
    }

    /// Absorbance as a percentage of the baseline's, both against the same clean water. It follows the dye in
    /// the bath: less dye, less absorbance. Nil without channels, or when the baseline has no absorbance.
    func concentration(relativeToRatios baseline: [Double], cleanRatios: [Double]) -> Double? {
        guard let ratios = channelRatios,
              let current = Self.absorbance(ratios: ratios, cleanRatios: cleanRatios),
              let initial = Self.absorbance(ratios: baseline, cleanRatios: cleanRatios),
              initial > 0
        else { return nil }
        return current / initial * 100
    }

    /// Percentage of `baseline`; nil when there is no positive baseline to compare with.
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

/// A Serona device found while scanning.
struct DiscoveredDevice: Identifiable, Hashable, Sendable {
    /// Shown while a device has not revealed its name yet.
    static let unnamed = "Tanpa Nama"

    let id: UUID
    let nama: String

    /// The name to show for a peripheral. The advertised name comes first because iOS caches `peripheralName`
    /// and can keep an old one. Blank names count as missing; nil means neither source has a name yet.
    nonisolated static func resolveName(peripheralName: String?, advertisedName: String?) -> String? {
        [advertisedName, peripheralName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }
}

/// Finds and connects to devices. This is all `DeviceListViewModel` needs.
protocol DeviceConnecting: Sendable {
    /// Emits each device as it is found and finishes when the scan ends.
    func scanDevices() -> AsyncThrowingStream<DiscoveredDevice, any Error>
    /// Connects to `device`. Cancelling the calling task abandons the attempt with `CancellationError`.
    func connect(to device: DiscoveredDevice) async throws
    /// Drops the connection to `device`.
    func disconnect(from device: DiscoveredDevice) async
}

/// Reads color measurements from a connected device. This is all `ProyekViewModel` needs.
protocol ColorMeasurementSource: Sendable {
    func readInitialColorMeasurement() async throws -> ColorMeasurement
    func measurementUpdates() -> AsyncStream<ColorMeasurement>
}

/// A device that can both connect and measure (the BLE and simulated implementations).
protocol DeviceConnectionService: DeviceConnecting, ColorMeasurementSource, Sendable {}

struct SimulatedDeviceConnectionService: DeviceConnectionService {
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

    func readInitialColorMeasurement() async throws -> ColorMeasurement {
        ColorMeasurement(visibleAverage: 1000, clear: 1000, nir: 100)
    }

    func measurementUpdates() -> AsyncStream<ColorMeasurement> {
        AsyncStream { continuation in
            continuation.yield(ColorMeasurement(visibleAverage: 1000, clear: 1000, nir: 100))
        }
    }
}
