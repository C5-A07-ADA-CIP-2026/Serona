//
//  StubDeviceConnectionService.swift
//  SeronaTests
//

import Foundation
@testable import Serona

/// Thread-safe counter for how many device reads a stub received.
final nonisolated class ReadCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = 0

    var value: Int {
        lock.withLock { storage }
    }

    /// Adds one and returns the new count.
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
    /// When set, the first `readInitialColorMeasurement` suspends until this stream yields or finishes.
    var readGate: AsyncStream<Void>?
    var onReadStarted: (@Sendable () -> Void)?
    /// When set, `measurementUpdates` returns this stream instead of `updates`.
    var liveUpdates: AsyncStream<ColorMeasurement>?
    /// When set, `readInitialColorMeasurement` throws this error (after the gate, if any).
    var readError: (any Error)?
    /// Counts every `readInitialColorMeasurement` call.
    let readCounter = ReadCounter()

    /// Devices `scanDevices` reports, then it finishes (with `scanError` when set).
    var devices: [DiscoveredDevice] = []
    var scanError: (any Error)?
    /// When set, `scanDevices` returns this stream instead of `devices`.
    var liveDevices: AsyncThrowingStream<DiscoveredDevice, any Error>?
    /// When set, `connect(to:)` throws this error.
    var connectError: (any Error)?
    /// When true, `connect(to:)` suspends until the task is cancelled.
    var connectSuspends = false
    /// Counts every `connect(to:)` call.
    let connectCounter = ReadCounter()
    /// Counts every `disconnect(from:)` call.
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
        // Only the first read waits: a gate stream supports a single consumer.
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
