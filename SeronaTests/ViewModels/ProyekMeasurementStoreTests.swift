//
//  ProyekMeasurementStoreTests.swift
//  SeronaTests
//

import Foundation
@testable import Serona
import Testing

/// A bak keeps measuring when its screen goes away (for example when the user opens the Resep tab),
/// because its view model lives in a store that outlives the Proyek list view.
@MainActor
struct ProyekMeasurementStoreTests {
    private func makeProyek() -> Proyek {
        Proyek(nama: "Seragam RT 5", perangkatNama: "ESP 32", resep: .sample(), jumlahKain: 3)
    }

    @Test("Asking twice for the same project returns the same view model")
    func sameViewModelPerProject() {
        let store = ProyekMeasurementStore()
        let proyek = makeProyek()

        let first = store.viewModel(for: proyek, service: StubDeviceConnectionService())
        let second = store.viewModel(for: proyek, service: StubDeviceConnectionService())

        #expect(first === second)
    }

    @Test("A running measurement survives the list view being rebuilt")
    func measurementSurvivesViewRebuild() async {
        let store = ProyekMeasurementStore()
        let proyek = makeProyek()
        let viewModel = store.viewModel(for: proyek, service: StubDeviceConnectionService(
            updates: [ColorMeasurement(visibleAverage: 735, clear: 1200, nir: 200, waterPH: 10.5)]
        ))
        await viewModel.pindaiDenganWarnaAwal()

        // The Proyek tab is torn down and shown again: it asks the store, it does not build anew.
        let afterTabSwitch = store.viewModel(for: proyek, service: StubDeviceConnectionService())
        let didUpdate = await waitUntil { afterTabSwitch.latestWaterPH == 10.5 }

        #expect(afterTabSwitch === viewModel)
        #expect(didUpdate)
        #expect(afterTabSwitch.isDataScanned)
    }

    @Test("Removing a project stops its measurement and forgets its view model")
    func removeStopsAndForgets() {
        let store = ProyekMeasurementStore()
        let proyek = makeProyek()
        let first = store.viewModel(for: proyek, service: StubDeviceConnectionService())

        store.remove(proyek.id)
        let second = store.viewModel(for: proyek, service: StubDeviceConnectionService())

        #expect(first !== second)
    }

    @Test("The store lists every view model it holds")
    func listsAll() {
        let store = ProyekMeasurementStore()
        _ = store.viewModel(for: makeProyek(), service: StubDeviceConnectionService())
        _ = store.viewModel(for: makeProyek(), service: StubDeviceConnectionService())

        #expect(store.allViewModels.count == 2)
    }
}
