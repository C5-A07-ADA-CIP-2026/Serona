//
//  ServiceSegregationTests.swift
//  SeronaTests
//

import Foundation
@testable import Serona
import Testing

/// Conforms only to `DeviceConnecting`: it cannot read colors.
private struct ConnectingOnlyService: DeviceConnecting {
    var devices = [DiscoveredDevice(id: UUID(), nama: "ESP 32")]

    func scanDevices() -> AsyncThrowingStream<DiscoveredDevice, any Error> {
        let devices = devices
        return AsyncThrowingStream { continuation in
            for device in devices {
                continuation.yield(device)
            }
            continuation.finish()
        }
    }

    func connect(to _: DiscoveredDevice) async throws {}

    func disconnect(from _: DiscoveredDevice) async {}
}

/// Conforms only to `ColorMeasurementSource`: it cannot connect.
private struct MeasurementOnlySource: ColorMeasurementSource {
    func readInitialColorMeasurement() async throws -> ColorMeasurement {
        ColorMeasurement(visibleAverage: 1000, clear: 1200, nir: 200)
    }

    func measurementUpdates() -> AsyncStream<ColorMeasurement> {
        AsyncStream { continuation in
            continuation.yield(ColorMeasurement(visibleAverage: 800, clear: 1200, nir: 200))
            continuation.finish()
        }
    }
}

@MainActor
struct ServiceSegregationTests {
    @Test("DeviceListViewModel needs only a DeviceConnecting service")
    func deviceListWorksWithConnectingOnlyService() async throws {
        let viewModel = DeviceListViewModel(service: ConnectingOnlyService())

        await viewModel.scan()
        #expect(viewModel.devices.count == 1)

        try await viewModel.connect(#require(viewModel.devices.first))
        #expect(viewModel.connectedDevice?.nama == "ESP 32")
    }

    @Test("ProyekDetailViewModel needs only a ColorMeasurementSource")
    func proyekDetailWorksWithMeasurementOnlySource() async {
        let proyek = Proyek(nama: "A", perangkatNama: "ESP 32", resep: .sample(batasKepekatan: 90), jumlahKain: 1)
        let viewModel = ProyekDetailViewModel(proyek: proyek, service: MeasurementOnlySource())

        await viewModel.pindaiDenganWarnaAwal()
        let didStream = await waitUntil { viewModel.latestConcentration == 80 }

        #expect(viewModel.isDataScanned)
        #expect(didStream)
    }
}
