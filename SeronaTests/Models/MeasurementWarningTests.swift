@testable import Serona
import Testing

@Suite("Measurement warning policy")
struct MeasurementWarningTests {
    @Test("Concentration warning uses the exact message for a whole-number limit")
    func concentrationMessageForWholeLimit() {
        var tracker = MeasurementWarningTracker()

        let message = tracker.concentrationWarning(for: 79.9, limit: 80)

        #expect(
            message == "Kepekatan warna saat ini di bawah 80%. Tambahkan 10 gram pewarna untuk "
                + "menjaga kualitas dan ketajaman warna batik."
        )
    }

    @Test("Concentration warning keeps fractional limits without trailing zeros")
    func concentrationMessageForFractionalLimit() {
        var tracker = MeasurementWarningTracker()

        let message = tracker.concentrationWarning(for: 50, limit: 87.5)

        #expect(
            message == "Kepekatan warna saat ini di bawah 87.5%. Tambahkan 10 gram pewarna untuk "
                + "menjaga kualitas dan ketajaman warna batik."
        )
    }

    @Test("Concentration warning is emitted once per dip")
    func concentrationWarnsOncePerDip() {
        var tracker = MeasurementWarningTracker()

        #expect(tracker.concentrationWarning(for: 79, limit: 80) != nil)
        #expect(tracker.concentrationWarning(for: 78, limit: 80) == nil)
        #expect(tracker.concentrationWarning(for: 10, limit: 80) == nil)
    }

    @Test("Concentration warning re-arms after the concentration recovers")
    func concentrationRearmsAfterRecovery() {
        var tracker = MeasurementWarningTracker()
        #expect(tracker.concentrationWarning(for: 79, limit: 80) != nil)

        #expect(tracker.concentrationWarning(for: 85, limit: 80) == nil)

        #expect(tracker.concentrationWarning(for: 79, limit: 80) != nil)
    }

    @Test("Concentration at exactly the limit does not warn and re-arms")
    func concentrationAtLimitDoesNotWarn() {
        var tracker = MeasurementWarningTracker()

        #expect(tracker.concentrationWarning(for: 80, limit: 80) == nil)
        #expect(tracker.concentrationWarning(for: 79, limit: 80) != nil)
        #expect(tracker.concentrationWarning(for: 80, limit: 80) == nil)
        #expect(tracker.concentrationWarning(for: 79, limit: 80) != nil)
    }

    @Test("Water pH warning uses the exact message")
    func waterPHMessage() {
        let message = MeasurementWarningTracker.waterPHWarning(for: 7.4, limit: 7.5)

        #expect(
            message == "pH air saat ini di bawah 7.5. Tambahkan 10 gram soda abu untuk menjaga "
                + "kualitas dan ketajaman warna batik."
        )
    }

    @Test("Water pH message formats a whole-number limit without decimals")
    func waterPHMessageForWholeLimit() {
        let message = MeasurementWarningTracker.waterPHWarning(for: 6, limit: 7)

        #expect(
            message == "pH air saat ini di bawah 7. Tambahkan 10 gram soda abu untuk menjaga "
                + "kualitas dan ketajaman warna batik."
        )
    }

    @Test("Water pH at or above the limit has no warning")
    func waterPHAtOrAboveLimit() {
        #expect(MeasurementWarningTracker.waterPHWarning(for: 7.5, limit: 7.5) == nil)
        #expect(MeasurementWarningTracker.waterPHWarning(for: 9, limit: 7.5) == nil)
    }

    @Test("Water pH warns on every reading below the limit")
    func waterPHWarnsRepeatedly() {
        #expect(MeasurementWarningTracker.waterPHWarning(for: 7, limit: 7.5) != nil)
        #expect(MeasurementWarningTracker.waterPHWarning(for: 6.9, limit: 7.5) != nil)
    }

    @Test("Reset lets the next dip warn again")
    func resetRearms() {
        var tracker = MeasurementWarningTracker()
        #expect(tracker.concentrationWarning(for: 79, limit: 80) != nil)
        #expect(tracker.concentrationWarning(for: 78, limit: 80) == nil)

        tracker.reset()

        #expect(tracker.concentrationWarning(for: 78, limit: 80) != nil)
    }
}
