import Foundation
@testable import Serona

final nonisolated class ReadCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = 0

    var value: Int {
        lock.withLock { storage }
    }

    func increment() -> Int {
        lock.withLock {
            storage += 1
            return storage
        }
    }
}

struct StubDeviceConnectionService: DeviceConnectionService, ColorMeasurementSource {
    var initial = ColorMeasurement(visibleAverage: 1000, clear: 1200, nir: 200)
    var updates: [ColorMeasurement] = []

    var readGate: AsyncStream<Void>?
    var onReadStarted: (@Sendable () -> Void)?

    var liveUpdates: AsyncStream<ColorMeasurement>?

    var readError: (any Error)?

    let readCounter = ReadCounter()

    var devices: [DiscoveredDevice] = []
    var scanError: (any Error)?

    var liveDevices: AsyncThrowingStream<DiscoveredDevice, any Error>?

    var connectError: (any Error)?

    var connectSuspends = false

    let connectCounter = ReadCounter()

    let disconnectCounter = ReadCounter()

    func scanDevices() -> AsyncThrowingStream<DiscoveredDevice, any Error> {
        if let liveDevices {
            return liveDevices
        }
        let devices = devices
        let scanError = scanError
        return AsyncThrowingStream { continuation in
            for device in devices {
                continuation.yield(device)
            }
            continuation.finish(throwing: scanError)
        }
    }

    func connect(to _: DiscoveredDevice) async throws {
        _ = connectCounter.increment()
        if connectSuspends {
            try await Task.sleep(for: .seconds(60))
        }
        if let connectError {
            throw connectError
        }
    }

    func disconnect(from _: DiscoveredDevice) async {
        _ = disconnectCounter.increment()
    }

    func measurementSource(for _: UUID) -> any ColorMeasurementSource {
        self
    }

    func readInitialColorMeasurement() async throws -> ColorMeasurement {
        let readNumber = readCounter.increment()
        onReadStarted?()

        if let readGate, readNumber == 1 {
            for await _ in readGate {
                break
            }
        }
        if let readError {
            throw readError
        }
        return initial
    }

    func measurementUpdates() -> AsyncStream<ColorMeasurement> {
        if let liveUpdates {
            return liveUpdates
        }
        let updates = updates
        return AsyncStream { continuation in
            for update in updates {
                continuation.yield(update)
            }
            continuation.finish()
        }
    }
}
