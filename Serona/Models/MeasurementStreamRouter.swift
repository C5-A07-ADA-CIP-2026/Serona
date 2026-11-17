import Foundation

/// Fan-out router used by BLE sessions. Measurements never cross device identifiers.
final nonisolated class MeasurementStreamRouter: @unchecked Sendable {
    private let lock = NSLock()
    private var continuations: [UUID: [UUID: AsyncStream<ColorMeasurement>.Continuation]] = [:]

    func stream(for deviceID: UUID) -> AsyncStream<ColorMeasurement> {
        AsyncStream { continuation in
            let subscriberID = UUID()
            lock.withLock {
                continuations[deviceID, default: [:]][subscriberID] = continuation
            }
            continuation.onTermination = { [weak self] _ in
                self?.remove(subscriberID, from: deviceID)
            }
        }
    }

    func yield(_ measurement: ColorMeasurement, for deviceID: UUID) {
        let targets = lock.withLock { Array(continuations[deviceID, default: [:]].values) }
        for continuation in targets {
            continuation.yield(measurement)
        }
    }

    func finish(deviceID: UUID) {
        let targets = lock.withLock { continuations.removeValue(forKey: deviceID).map { Array($0.values) } ?? [] }
        for continuation in targets {
            continuation.finish()
        }
    }

    private func remove(_ subscriberID: UUID, from deviceID: UUID) {
        lock.withLock {
            continuations[deviceID]?.removeValue(forKey: subscriberID)
            if continuations[deviceID]?.isEmpty == true {
                continuations.removeValue(forKey: deviceID)
            }
        }
    }
}
