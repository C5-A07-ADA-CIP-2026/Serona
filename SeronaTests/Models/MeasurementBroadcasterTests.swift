//
//  MeasurementBroadcasterTests.swift
//  SeronaTests
//

import Foundation
@testable import Serona
import Testing

@Suite("Measurement broadcaster")
@MainActor
struct MeasurementBroadcasterTests {
    private func reading(_ value: Double) -> ColorMeasurement {
        ColorMeasurement(visibleAverage: value, clear: 1000, nir: 100)
    }

    @Test("Every open stream receives each reading, not only the newest one")
    func everyStreamReceivesReadings() async {
        let broadcaster = MeasurementBroadcaster()
        var first = broadcaster.stream().makeAsyncIterator()
        var second = broadcaster.stream().makeAsyncIterator()

        broadcaster.yield(reading(42))

        #expect(await first.next()?.visibleAverage == 42)
        #expect(await second.next()?.visibleAverage == 42)
    }

    @Test("Finishing ends every stream")
    func finishEndsEveryStream() async {
        let broadcaster = MeasurementBroadcaster()
        var first = broadcaster.stream().makeAsyncIterator()
        var second = broadcaster.stream().makeAsyncIterator()

        broadcaster.finishAll()

        #expect(await first.next() == nil)
        #expect(await second.next() == nil)
    }

    @Test("A stream that was cancelled stops being counted")
    func cancelledStreamIsRemoved() async {
        let broadcaster = MeasurementBroadcaster()
        let task = Task {
            for await _ in broadcaster.stream() {}
        }
        #expect(await waitUntil { broadcaster.streamCount == 1 })

        task.cancel()

        #expect(await waitUntil { broadcaster.streamCount == 0 })
    }
}
