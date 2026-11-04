//
//  ProyekDetailViewModel+Scan.swift
//  SeronaTests
//

@testable import Serona

extension ProyekDetailViewModel {
    /// Scans, then sets the initial color from the scan's own reading.
    /// No suspension point separates the two calls, so the stream cannot replace that reading in between.
    func pindaiDenganWarnaAwal(in persistence: RecordingModelPersistence = RecordingModelPersistence()) async {
        await mulaiPindai()
        tetapkanWarnaAwal(in: persistence)
    }
}
