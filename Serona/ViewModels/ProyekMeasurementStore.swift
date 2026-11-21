//
//  ProyekMeasurementStore.swift
//  Serona
//

import Foundation
import Observation

/// Owns the view model of every active bak, so a bak keeps measuring while its screen is gone
/// (the user opens the Resep tab) and for as long as the app runs. It lives above the tab views,
/// never inside one: a view that owns a measurement stops it when SwiftUI removes the view.
@MainActor
@Observable
final class ProyekMeasurementStore {
    @ObservationIgnored private var viewModels: [UUID: ProyekDetailViewModel] = [:]

    var allViewModels: [ProyekDetailViewModel] {
        Array(viewModels.values)
    }

    /// The running view model of `proyek`, made on first use.
    func viewModel(for proyek: Proyek, service: (any ColorMeasurementSource)?) -> ProyekDetailViewModel {
        if let existing = viewModels[proyek.id] {
            return existing
        }
        let viewModel = ProyekDetailViewModel(proyek: proyek, service: service)
        viewModels[proyek.id] = viewModel
        return viewModel
    }

    /// Stops the measurement of `projectID` and forgets it (the bak is finished or set up again).
    func remove(_ projectID: UUID) {
        viewModels.removeValue(forKey: projectID)?.berhenti()
    }
}
