import SwiftData
import SwiftUI

#Preview("3 Stages Grid (iPad Landscape)", traits: .landscapeLeft) {
    BakCardStagesPreview()
}

#Preview("Connection Status – Accessibility 5") {
    ScrollView {
        BakCardView(proyek: .previewActiveSample)
            .padding()
    }
    .environment(\.dynamicTypeSize, .accessibility5)
}

private struct BakCardStagesPreview: View {
    @StateObject private var activeVM = ProyekDetailViewModel(
        proyek: .previewActiveSample,
        service: PreviewMeasurementSource(
            measurement: ColorMeasurement(visibleAverage: 95, clear: 100, nir: 100, waterPH: 12)
        )
    )

    @StateObject private var warningVM = ProyekDetailViewModel(
        proyek: .previewWarningSample,
        service: PreviewMeasurementSource(
            measurement: ColorMeasurement(visibleAverage: 87, clear: 100, nir: 100, waterPH: 8)
        )
    )

    var body: some View {
        ZStack {
            BackgroundGradient()

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 20),
                    GridItem(.flexible(), spacing: 20),
                    GridItem(.flexible(), spacing: 20),
                ],
                spacing: 20
            ) {
                BakCardView(proyek: .previewActiveSample, viewModel: activeVM)
                BakCardView(proyek: .previewInactiveSample)
                BakCardView(proyek: .previewWarningSample, viewModel: warningVM)
            }
            .padding(24)
        }
        .task {
            await activeVM.mulaiPindai()
            await warningVM.mulaiPindai()
        }
    }
}

private struct PreviewMeasurementSource: ColorMeasurementSource {
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
    static var previewActiveSample: Proyek {
        Proyek(
            nama: "Bak 1",
            perangkatNama: "Bu Fanny",
            resep: Resep(
                namaWarna: "Merah Maroon", warnaHex: "#7A1C33",
                air: 1000, kepekatan: 80, batasPH: 7
            ),
            jumlahKain: 2
        )
    }

    static var previewInactiveSample: Proyek {
        let proyek = Proyek(
            nama: "Bak 2",
            perangkatNama: "-",
            resep: Resep(
                namaWarna: "-", warnaHex: "#8E8E93",
                air: 1000, kepekatan: 80, batasPH: 7
            ),
            jumlahKain: 1
        )
        proyek.selesaikan(kepekatanAkhir: nil, phAkhir: nil)
        return proyek
    }

    static var previewWarningSample: Proyek {
        Proyek(
            nama: "Bak 3",
            perangkatNama: "Bu Fanny",
            resep: Resep(
                namaWarna: "Krem", warnaHex: "#EB9675",
                air: 1000, kepekatan: 80, batasPH: 7
            ),
            jumlahKain: 3
        )
    }
}
