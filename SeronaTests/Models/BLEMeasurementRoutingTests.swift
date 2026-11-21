import Foundation
@testable import Serona
import Testing

@MainActor
struct MeasurementStreamRouterTests {
    @Test("Measurements are routed only to subscribers for the matching sensor")
    func routesByDeviceIdentifier() async {
        let router = MeasurementStreamRouter()
        let sensorA = UUID()
        let sensorB = UUID()
        let streamA = router.stream(for: sensorA)
        let streamB = router.stream(for: sensorB)
        let expectedA = ColorMeasurement(visibleAverage: 100, clear: 10, nir: 1)
        let expectedB = ColorMeasurement(visibleAverage: 200, clear: 20, nir: 2)

        router.yield(expectedA, for: sensorA)
        router.yield(expectedB, for: sensorB)

        var iteratorA = streamA.makeAsyncIterator()
        var iteratorB = streamB.makeAsyncIterator()
        #expect(await iteratorA.next() == expectedA)
        #expect(await iteratorB.next() == expectedB)
    }

    @Test("Multiple subscribers to one sensor receive the same measurement")
    func fansOutToMultipleSubscribers() async {
        let router = MeasurementStreamRouter()
        let sensor = UUID()
        let first = router.stream(for: sensor)
        let second = router.stream(for: sensor)
        let expected = ColorMeasurement(visibleAverage: 100, clear: 10, nir: 1)

        router.yield(expected, for: sensor)

        var firstIterator = first.makeAsyncIterator()
        var secondIterator = second.makeAsyncIterator()
        #expect(await firstIterator.next() == expected)
        #expect(await secondIterator.next() == expected)
    }
}

@MainActor
struct MeasurementFrameDecoderTests {
    @Test("A JSON measurement can arrive in multiple BLE fragments")
    func reassemblesFragments() throws {
        var decoder = MeasurementFrameDecoder()
        #expect(try decoder.append(Data(#"{"visibleAverage":10,"clear":20,"#.utf8)).isEmpty)
        let frames = try decoder.append(Data(#""nir":2}"#.utf8))
        #expect(frames.count == 1)
        let measurement = try JSONDecoder().decode(ColorMeasurement.self, from: #require(frames.first))
        #expect(measurement.visibleAverage == 10)
    }

    @Test("Multiple JSON measurements in one BLE callback are separated")
    func separatesFrames() throws {
        var decoder = MeasurementFrameDecoder()
        let json = #"{"visibleAverage":1,"clear":2,"nir":3}{"visibleAverage":4,"clear":5,"nir":6}"#
        let frames = try decoder.append(Data(json.utf8))
        #expect(frames.count == 2)
    }

    @Test("Invalid channel count is rejected")
    func validatesChannelCount() throws {
        let data = Data(#"{"visibleAverage":1,"clear":2,"clear1":2,"nir":3,"channels":[1]}"#.utf8)
        let decoded = try JSONDecoder().decode(ColorMeasurement.self, from: data)
        #expect(throws: MeasurementPayloadError.invalidChannels) {
            try decoded.validated()
        }
    }
}
