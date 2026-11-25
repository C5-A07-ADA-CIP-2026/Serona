import SwiftData
import SwiftUI

#Preview("Tahap 1: Volume Air (0 L)", traits: .landscapeLeft) {
    PerbaikiLarutanStepPreview(
        previewID: "step1-0L",
        step: .air,
        jumlahAir: 0,
        visibleAverage: 72,
        waterPH: 8
    )
}

#Preview("Tahap 1: Volume Air (1 L)", traits: .landscapeLeft) {
    PerbaikiLarutanStepPreview(
        previewID: "step1-1L",
        step: .air,
        jumlahAir: 1,
        visibleAverage: 72,
        waterPH: 8
    )
}

#Preview("Tahap 2: pH Air (pH 8)", traits: .landscapeLeft) {
    PerbaikiLarutanStepPreview(
        previewID: "step2-ph8",
        step: .phAir,
        jumlahAir: 1,
        visibleAverage: 72,
        waterPH: 8
    )
}

#Preview("Tahap 2: pH Air (Target 12)", traits: .landscapeLeft) {
    PerbaikiLarutanStepPreview(
        previewID: "step2-ph12",
        step: .phAir,
        jumlahAir: 1,
        visibleAverage: 72,
        waterPH: 12
    )
}

#Preview("Tahap 3: Kepekatan (72%)", traits: .landscapeLeft) {
    PerbaikiLarutanStepPreview(
        previewID: "step3-72",
        step: .kepekatan,
        jumlahAir: 1,
        visibleAverage: 72,
        waterPH: 12
    )
}

#Preview("Tahap 3: Kepekatan (Target 100%)", traits: .landscapeLeft) {
    PerbaikiLarutanStepPreview(
        previewID: "step3-100",
        step: .kepekatan,
        jumlahAir: 1,
        visibleAverage: 100,
        waterPH: 12
    )
}

private struct PerbaikiLarutanStepPreview: View {
    let previewID: String
    let step: PerbaikiStep
    let jumlahAir: Int
    @StateObject private var previewViewModel: ProyekDetailViewModel

    init(
        previewID: String,
        step: PerbaikiStep,
        jumlahAir: Int,
        visibleAverage: Double,
        waterPH: Double
    ) {
        self.previewID = previewID
        self.step = step
        self.jumlahAir = jumlahAir
        _previewViewModel = StateObject(wrappedValue: ProyekDetailViewModel(
            proyek: .previewRepairSample,
            service: PreviewRepairMeasurementSource(
                measurement: ColorMeasurement(
                    visibleAverage: visibleAverage,
                    clear: 1000,
                    nir: 100,
                    waterPH: waterPH
                )
            )
        ))
    }

    var body: some View {
        ZStack {
            BackgroundGradient()

            Color.black.opacity(0.28)
                .ignoresSafeArea()

            PerbaikiLarutanView(
                issue: .keduanya,
                viewModel: previewViewModel,
                initialStep: step,
                initialJumlahAir: jumlahAir
            )
            .task(id: previewID) {
                await previewViewModel.mulaiPindai()
            }
        }
        .id(previewID)
    }
}

private struct PreviewRepairMeasurementSource: ColorMeasurementSource {
    let measurement: ColorMeasurement

    func readInitialColorMeasurement() async throws -> ColorMeasurement {
        measurement
    }

    func measurementUpdates() -> AsyncStream<ColorMeasurement> {
        AsyncStream { continuation in
            continuation.yield(measurement)
        }
    }
}

private extension Proyek {
    static var previewRepairSample: Proyek {
        let proyek = Proyek(
            nama: "Bak 5",
            perangkatNama: "Bu Fanny",
            resep: Resep(
                namaWarna: "Merah Ungu Dina",
                warnaHex: "#933C64",
                air: 5,
                kepekatan: 90,
                batasPH: 11,
                pewarna: [Bahan(kode: "Napthol AS", gram: 50)],
                zatPembantu: [Bahan(kode: "Soda Abu", gram: 10)]
            ),
            jumlahKain: 2
        )
        proyek.visibleAverageAwal = 100
        proyek.phAwal = 12
        return proyek
    }
}
