//
//  ProyekDetailQualityAlertTests.swift
//  SeronaTests
//

import Foundation
@testable import Serona
import Testing

@MainActor
struct ProyekDetailQualityAlertTests {
    private func makeProyek(batasKepekatan: Double = 80, batasPH: Double = 7) -> Proyek {
        Proyek(
            nama: "Seragam RT 5",
            perangkatNama: "ESP 32",
            resep: .sample(batasKepekatan: batasKepekatan, batasPH: batasPH),
            jumlahKain: 3
        )
    }

    private func makeViewModel(proyek: Proyek, service: StubDeviceConnectionService) -> ProyekDetailViewModel {
        ProyekDetailViewModel(proyek: proyek, service: service)
    }

    private func makeLiveViewModel(
        batasKepekatan: Double = 80,
        batasPH: Double = 10
    ) async -> (ProyekDetailViewModel, AsyncStream<ColorMeasurement>.Continuation) {
        let (updates, liveReadings) = AsyncStream<ColorMeasurement>.makeStream()
        let viewModel = makeViewModel(
            proyek: makeProyek(batasKepekatan: batasKepekatan, batasPH: batasPH),
            service: StubDeviceConnectionService(
                initial: ColorMeasurement(visibleAverage: 1000, clear: 1200, nir: 200, waterPH: 12),
                liveUpdates: updates
            )
        )
        await viewModel.pindaiDenganWarnaAwal()
        return (viewModel, liveReadings)
    }

    @Test("Nothing is low and no alert shows while both readings are above their limits")
    func noAlertWhileAboveLimits() async {
        let (viewModel, liveReadings) = await makeLiveViewModel()

        liveReadings.yield(ColorMeasurement(visibleAverage: 900, clear: 1200, nir: 200, waterPH: 11))
        let didConsume = await waitUntil { viewModel.latestWaterPH == 11 }

        #expect(didConsume)
        #expect(!viewModel.isConcentrationLow)
        #expect(!viewModel.isWaterPHLow)
        #expect(viewModel.qualityAlert == nil)
    }

    @Test("A low concentration alone is flagged and alerts about the concentration only")
    func lowConcentrationAlert() async {
        let (viewModel, liveReadings) = await makeLiveViewModel()

        liveReadings.yield(ColorMeasurement(visibleAverage: 720, clear: 1200, nir: 200, waterPH: 11))
        let didAlert = await waitUntil { viewModel.qualityAlert != nil }

        #expect(didAlert)
        #expect(viewModel.isConcentrationLow)
        #expect(!viewModel.isWaterPHLow)
        #expect(viewModel.qualityAlert?.issue == .kepekatan)
        #expect(viewModel.qualityAlert?.message.hasPrefix("Kepekatan warna saat ini di bawah 80%.") == true)
    }

    @Test("A low pH alone is flagged and alerts about the pH only")
    func lowPHAlert() async {
        let (viewModel, liveReadings) = await makeLiveViewModel()

        liveReadings.yield(ColorMeasurement(visibleAverage: 900, clear: 1200, nir: 200, waterPH: 9))
        let didAlert = await waitUntil { viewModel.qualityAlert != nil }

        #expect(didAlert)
        #expect(viewModel.isWaterPHLow)
        #expect(!viewModel.isConcentrationLow)
        #expect(viewModel.qualityAlert?.issue == .phAir)
        #expect(viewModel.qualityAlert?.message.hasPrefix("pH air saat ini di bawah 10.") == true)
    }

    @Test("Both readings low alert about both")
    func bothLowAlert() async {
        let (viewModel, liveReadings) = await makeLiveViewModel()

        liveReadings.yield(ColorMeasurement(visibleAverage: 720, clear: 1200, nir: 200, waterPH: 9))
        let didAlert = await waitUntil { viewModel.qualityAlert != nil }

        #expect(didAlert)
        #expect(viewModel.qualityAlert?.issue == .keduanya)
    }

    @Test("A dismissed alert stays dismissed while the reading stays low, and the row stays flagged")
    func dismissedAlertStaysDismissed() async {
        let (viewModel, liveReadings) = await makeLiveViewModel()
        liveReadings.yield(ColorMeasurement(visibleAverage: 720, clear: 1200, nir: 200, waterPH: 11))
        let didAlert = await waitUntil { viewModel.qualityAlert != nil }
        #expect(didAlert)

        viewModel.clearQualityAlert()
        liveReadings.yield(ColorMeasurement(visibleAverage: 700, clear: 1200, nir: 200, waterPH: 11))
        let didConsume = await waitUntil { viewModel.latestConcentration == 70 }

        #expect(didConsume)
        #expect(viewModel.qualityAlert == nil)
        #expect(viewModel.isConcentrationLow)
    }

    @Test("A reading that recovers is no longer flagged, and a new dip alerts again")
    func recoveryThenNewDipAlerts() async {
        let (viewModel, liveReadings) = await makeLiveViewModel()
        liveReadings.yield(ColorMeasurement(visibleAverage: 720, clear: 1200, nir: 200, waterPH: 11))
        _ = await waitUntil { viewModel.qualityAlert != nil }
        viewModel.clearQualityAlert()

        liveReadings.yield(ColorMeasurement(visibleAverage: 900, clear: 1200, nir: 200, waterPH: 11))
        let didRecover = await waitUntil { !viewModel.isConcentrationLow }
        #expect(didRecover)

        liveReadings.yield(ColorMeasurement(visibleAverage: 700, clear: 1200, nir: 200, waterPH: 11))
        let didAlertAgain = await waitUntil { viewModel.qualityAlert != nil }
        #expect(didAlertAgain)
    }

    @Test("The alert can be shown again after it was dismissed while a reading is still low")
    func alertCanBeReopened() async {
        let (viewModel, liveReadings) = await makeLiveViewModel()
        liveReadings.yield(ColorMeasurement(visibleAverage: 720, clear: 1200, nir: 200, waterPH: 9))
        _ = await waitUntil { viewModel.qualityAlert != nil }
        viewModel.clearQualityAlert()

        viewModel.tampilkanQualityAlert()

        #expect(viewModel.qualityAlert?.issue == .keduanya)
    }

    @Test("Reopening shows what is low right now")
    func reopenedAlertFollowsCurrentReadings() async {
        let (viewModel, liveReadings) = await makeLiveViewModel()
        liveReadings.yield(ColorMeasurement(visibleAverage: 720, clear: 1200, nir: 200, waterPH: 9))
        _ = await waitUntil { viewModel.qualityAlert != nil }
        viewModel.clearQualityAlert()
        liveReadings.yield(ColorMeasurement(visibleAverage: 900, clear: 1200, nir: 200, waterPH: 9))
        _ = await waitUntil { !viewModel.isConcentrationLow }

        viewModel.tampilkanQualityAlert()

        #expect(viewModel.qualityAlert?.issue == .phAir)
    }

    @Test("There is nothing to reopen while no reading is low")
    func nothingToReopen() async {
        let (viewModel, liveReadings) = await makeLiveViewModel()
        liveReadings.yield(ColorMeasurement(visibleAverage: 900, clear: 1200, nir: 200, waterPH: 11))
        _ = await waitUntil { viewModel.latestWaterPH == 11 }

        viewModel.tampilkanQualityAlert()

        #expect(viewModel.qualityAlert == nil)
    }
}
