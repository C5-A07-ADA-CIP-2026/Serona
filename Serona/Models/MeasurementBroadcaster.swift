//
//  MeasurementBroadcaster.swift
//  Serona
//

import Foundation

/// Hands every live reading to all open streams. The device is shared by every project card, so each card's
/// stream must receive the readings; a single slot would leave only the newest card updating.
final nonisolated class MeasurementBroadcaster: @unchecked Sendable {
    private let lock = NSLock()
    private var continuations: [UUID: AsyncStream<ColorMeasurement>.Continuation] = [:]

    /// The number of streams that are still open.
    var streamCount: Int {
        lock.withLock { continuations.count }
    }

    /// A new stream that receives every reading yielded after this call, until it is cancelled or finished.
    func stream() -> AsyncStream<ColorMeasurement> {
        AsyncStream { continuation in
            let id = UUID()
            lock.withLock { continuations[id] = continuation }
            continuation.onTermination = { [weak self] _ in
                self?.lock.withLock { _ = self?.continuations.removeValue(forKey: id) }
            }
        }
    }

    func yield(_ measurement: ColorMeasurement) {
        let open = lock.withLock { Array(continuations.values) }
        for continuation in open {
            continuation.yield(measurement)
        }
    }

    /// Ends every open stream (the device disconnected).
    func finishAll() {
        let open = lock.withLock {
            let all = Array(continuations.values)
            continuations.removeAll()
            return all
        }
        for continuation in open {
            continuation.finish()
        }
    }
}
