import Foundation
import Observation

@MainActor
@Observable
final class ProyekMeasurementStore {
    @ObservationIgnored private var viewModels: [UUID: ProyekDetailViewModel] = [:]

    var allViewModels: [ProyekDetailViewModel] {
        Array(viewModels.values)
    }

    func viewModel(for proyek: Proyek, service: (any ColorMeasurementSource)?) -> ProyekDetailViewModel {
        if let existing = viewModels[proyek.id] {
            return existing
        }
        let viewModel = ProyekDetailViewModel(proyek: proyek, service: service)
        viewModels[proyek.id] = viewModel
        return viewModel
    }

    func remove(_ projectID: UUID) {
        viewModels.removeValue(forKey: projectID)?.berhenti()
    }
}
