@testable import Serona

extension ProyekDetailViewModel {
    func pindaiDenganWarnaAwal(in persistence: RecordingModelPersistence = RecordingModelPersistence()) async {
        await mulaiPindai()
        tetapkanWarnaAwal(in: persistence)
    }
}
