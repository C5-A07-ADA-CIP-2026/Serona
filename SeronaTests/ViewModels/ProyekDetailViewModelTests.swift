//
//  ProyekDetailViewModelTests.swift
//  SeronaTests
//

import Foundation
@testable import Serona
import Testing

@MainActor
struct ProyekDetailViewModelTests {
    private func makeProyek(batasKepekatan: Double = 80, batasPH: Double = 7) -> Proyek {
        Proyek(
            nama: "Seragam RT 5",
            perangkatNama: "ESP 32",
            resep: .sample(batasKepekatan: batasKepekatan, batasPH: batasPH),
            jumlahKain: 3
        )
    }

    private func makeViewModel(
        proyek: Proyek? = nil,
        service: StubDeviceConnectionService = StubDeviceConnectionService()
    ) -> ProyekDetailViewModel {
        ProyekDetailViewModel(proyek: proyek ?? makeProyek(), service: service)
    }

    // MARK: Before scanning

    @Test("Starts unscanned with the limits of the project")
    func startsWithProjectLimits() {
        let viewModel = makeViewModel(proyek: makeProyek(batasKepekatan: 90, batasPH: 7.5))

        #expect(viewModel.measurements.colorConcentrationLimit == 90)
        #expect(viewModel.measurements.waterPHLimit == 7.5)
        #expect(!viewModel.isDataScanned)
        #expect(!viewModel.isScanning)
        #expect(viewModel.latestConcentration == nil)
        #expect(viewModel.latestWaterPH == nil)
    }

    // MARK: Scanning

    @Test("Scanning reads the baseline and streams current values")
    func scanStreamsCurrentValues() async {
        let viewModel = makeViewModel(service: StubDeviceConnectionService(
            initial: ColorMeasurement(visibleAverage: 1000, clear: 1200, nir: 200, waterPH: 11),
            updates: [ColorMeasurement(visibleAverage: 735, clear: 1200, nir: 200, waterPH: 10.5)]
        ))

        await viewModel.pindaiDenganWarnaAwal()
        let didUpdate = await waitUntil { viewModel.measurements.current.first?.value == "73.5%" }

        #expect(didUpdate)
        #expect(viewModel.isDataScanned)
        #expect(viewModel.measurements.initial[0].value == "100%")
        #expect(viewModel.measurements.initial[2].value == "—")
        #expect(viewModel.measurements.current[1].value == "10.5")
        #expect(viewModel.latestConcentration == 73.5)
        #expect(viewModel.latestWaterPH == 10.5)
    }

    @Test("Warns when the concentration falls below the project limit")
    func warnsBelowConcentrationLimit() async {
        let viewModel = makeViewModel(
            proyek: makeProyek(batasKepekatan: 90),
            service: StubDeviceConnectionService(
                updates: [ColorMeasurement(visibleAverage: 850, clear: 1200, nir: 200)]
            )
        )

        await viewModel.pindaiDenganWarnaAwal()
        let didWarn = await waitUntil { viewModel.colorConcentrationWarning != nil }

        #expect(didWarn)
        #expect(viewModel.colorConcentrationWarning?.hasPrefix("Kepekatan warna saat ini di bawah 90%.") == true)
    }

    @Test("Does not warn at exactly the concentration limit")
    func doesNotWarnAtConcentrationLimit() async {
        let viewModel = makeViewModel(
            proyek: makeProyek(batasKepekatan: 90),
            service: StubDeviceConnectionService(
                updates: [ColorMeasurement(visibleAverage: 900, clear: 1200, nir: 200)]
            )
        )

        await viewModel.pindaiDenganWarnaAwal()
        let didConsume = await waitUntil { viewModel.measurements.current.first?.value == "90.0%" }

        #expect(didConsume)
        #expect(viewModel.colorConcentrationWarning == nil)
    }

    @Test("Warns when water pH falls below the project limit and clears when it recovers")
    func warnsBelowPHLimitThenClears() async {
        let (updates, liveReadings) = AsyncStream<ColorMeasurement>.makeStream()
        let viewModel = makeViewModel(
            proyek: makeProyek(batasPH: 7.5),
            service: StubDeviceConnectionService(liveUpdates: updates)
        )
        await viewModel.pindaiDenganWarnaAwal()

        liveReadings.yield(ColorMeasurement(visibleAverage: 1000, clear: 1200, nir: 200, waterPH: 7.4))
        let didWarn = await waitUntil { viewModel.waterPHWarning != nil }
        #expect(didWarn)
        #expect(viewModel.waterPHWarning?.hasPrefix("pH air saat ini di bawah 7.5.") == true)

        liveReadings.yield(ColorMeasurement(visibleAverage: 1000, clear: 1200, nir: 200, waterPH: 7.5))
        let didClear = await waitUntil { viewModel.waterPHWarning == nil }
        #expect(didClear)
    }

    @Test("Overlapping scans issue only one device read and show no error")
    func overlappingScansReadOnce() async {
        let (readGate, releaseRead) = AsyncStream<Void>.makeStream()
        let (readStarted, signalReadStarted) = AsyncStream<Void>.makeStream()
        let service = StubDeviceConnectionService(
            readGate: readGate,
            onReadStarted: { signalReadStarted.yield() }
        )
        let viewModel = makeViewModel(service: service)

        let first = Task { await viewModel.mulaiPindai() }
        for await _ in readStarted {
            break
        }
        let second = Task { await viewModel.mulaiPindai() }
        _ = await waitUntil(timeout: .milliseconds(100)) { service.readCounter.value > 1 }
        releaseRead.yield()
        releaseRead.finish()
        await first.value
        await second.value

        #expect(service.readCounter.value == 1)
        #expect(viewModel.colorMeasurementError == nil)
        #expect(viewModel.isDataScanned)
    }

    @Test("isScanning is true while the read is in flight and false afterwards")
    func isScanningTracksTheRead() async {
        let (readGate, releaseRead) = AsyncStream<Void>.makeStream()
        let (readStarted, signalReadStarted) = AsyncStream<Void>.makeStream()
        let viewModel = makeViewModel(service: StubDeviceConnectionService(
            readGate: readGate,
            onReadStarted: { signalReadStarted.yield() }
        ))

        let scan = Task { await viewModel.mulaiPindai() }
        for await _ in readStarted {
            break
        }
        #expect(viewModel.isScanning)

        releaseRead.yield()
        releaseRead.finish()
        await scan.value

        #expect(!viewModel.isScanning)
        #expect(viewModel.isDataScanned)
    }

    @Test("A cancelled read is not an error")
    func cancelledReadShowsNoError() async {
        let viewModel = makeViewModel(service: StubDeviceConnectionService(readError: CancellationError()))

        await viewModel.pindaiDenganWarnaAwal()

        #expect(viewModel.colorMeasurementError == nil)
        #expect(!viewModel.isDataScanned)
        #expect(!viewModel.isScanning)
    }

    @Test("A failed read shows the error, stops scanning and can be dismissed")
    func failedReadShowsError() async {
        struct ReadFailure: Error {}
        let viewModel = makeViewModel(service: StubDeviceConnectionService(readError: ReadFailure()))

        await viewModel.pindaiDenganWarnaAwal()

        #expect(viewModel.colorMeasurementError?.hasPrefix("Gagal membaca data warna") == true)
        #expect(!viewModel.isDataScanned)
        #expect(!viewModel.isScanning)

        viewModel.clearColorMeasurementError()
        #expect(viewModel.colorMeasurementError == nil)
    }

    @Test("Stopping ends the live stream: later readings change nothing")
    func stopEndsStream() async {
        let (updates, liveReadings) = AsyncStream<ColorMeasurement>.makeStream()
        let viewModel = makeViewModel(service: StubDeviceConnectionService(liveUpdates: updates))
        await viewModel.pindaiDenganWarnaAwal()
        liveReadings.yield(ColorMeasurement(visibleAverage: 950, clear: 1200, nir: 200))
        let isStreaming = await waitUntil { viewModel.latestConcentration == 95 }
        #expect(isStreaming)

        viewModel.berhenti()
        liveReadings.yield(ColorMeasurement(visibleAverage: 500, clear: 1200, nir: 200, waterPH: 1))
        let didChange = await waitUntil(timeout: .milliseconds(300)) {
            viewModel.latestConcentration != 95 || viewModel.waterPHWarning != nil
        }

        #expect(!didChange)
    }

    // MARK: Finishing

    @Test("Finishing without a scan does nothing")
    func finishWithoutScanDoesNothing() {
        let proyek = makeProyek()
        let persistence = RecordingModelPersistence()
        let viewModel = makeViewModel(proyek: proyek)

        let didFinish = viewModel.selesaikan(in: persistence)

        #expect(!didFinish)
        #expect(proyek.status == .aktif)
        #expect(persistence.events.isEmpty)
    }

    @Test("Finishing after a scan saves the final readings and makes the project inactive")
    func finishStoresFinalReadings() async {
        let proyek = makeProyek()
        let persistence = RecordingModelPersistence()
        let viewModel = makeViewModel(proyek: proyek, service: StubDeviceConnectionService(
            updates: [ColorMeasurement(visibleAverage: 850, clear: 1200, nir: 200, waterPH: 6.5)]
        ))
        await viewModel.pindaiDenganWarnaAwal()
        let didStream = await waitUntil { viewModel.latestConcentration == 85 }
        #expect(didStream)

        let didFinish = viewModel.selesaikan(in: persistence)

        #expect(didFinish)
        #expect(proyek.status == .nonaktif)
        #expect(proyek.kepekatanAkhir == 85)
        #expect(proyek.phAkhir == 6.5)
        #expect(persistence.events == [.save])
    }

    @Test("Final readings are nil when the initial color was never set and the sensor sent no pH")
    func finishBeforeInitialColorIsSet() async {
        let proyek = makeProyek()
        let viewModel = makeViewModel(proyek: proyek)
        await viewModel.mulaiPindai()

        let didFinish = viewModel.selesaikan(in: RecordingModelPersistence())

        #expect(didFinish)
        #expect(proyek.kepekatanAkhir == nil)
        #expect(proyek.phAkhir == nil)
    }

    @Test("A failed save reports the error and keeps the project active")
    func finishSaveFailureKeepsProjectActive() async {
        let proyek = makeProyek()
        let persistence = RecordingModelPersistence()
        persistence.saveError = StubSaveError()
        let viewModel = makeViewModel(proyek: proyek, service: StubDeviceConnectionService(
            updates: [ColorMeasurement(visibleAverage: 850, clear: 1200, nir: 200, waterPH: 6.5)]
        ))
        await viewModel.pindaiDenganWarnaAwal()
        let didStream = await waitUntil { viewModel.latestConcentration == 85 }
        #expect(didStream)

        let didFinish = viewModel.selesaikan(in: persistence)

        #expect(!didFinish)
        #expect(viewModel.saveError == "Gagal menyimpan proyek: disk penuh")
        #expect(proyek.status == .aktif)
        #expect(proyek.kepekatanAkhir == nil)
        #expect(proyek.phAkhir == nil)
        #expect(viewModel.isDataScanned)
    }

    @Test("After a failed save a retry can succeed")
    func finishRetryAfterFailure() async {
        let proyek = makeProyek()
        let persistence = RecordingModelPersistence()
        persistence.saveError = StubSaveError()
        let viewModel = makeViewModel(proyek: proyek)
        await viewModel.pindaiDenganWarnaAwal()
        #expect(!viewModel.selesaikan(in: persistence))

        persistence.saveError = nil
        viewModel.clearSaveError()

        #expect(viewModel.selesaikan(in: persistence))
        #expect(viewModel.saveError == nil)
        #expect(proyek.status == .nonaktif)
    }

    @Test("Finishing twice saves once")
    func finishTwiceSavesOnce() async {
        let persistence = RecordingModelPersistence()
        let viewModel = makeViewModel()
        await viewModel.pindaiDenganWarnaAwal()
        #expect(viewModel.selesaikan(in: persistence))

        #expect(!viewModel.selesaikan(in: persistence))

        #expect(persistence.events == [.save])
    }

    @Test("Finishing ends the live stream")
    func finishEndsStream() async {
        let (updates, liveReadings) = AsyncStream<ColorMeasurement>.makeStream()
        let viewModel = makeViewModel(service: StubDeviceConnectionService(liveUpdates: updates))
        await viewModel.pindaiDenganWarnaAwal()
        #expect(viewModel.selesaikan(in: RecordingModelPersistence()))

        liveReadings.yield(ColorMeasurement(visibleAverage: 500, clear: 1200, nir: 200, waterPH: 1))
        let didChange = await waitUntil(timeout: .milliseconds(300)) {
            viewModel.latestConcentration == 50 || viewModel.waterPHWarning != nil
        }

        #expect(!didChange)
    }
}
