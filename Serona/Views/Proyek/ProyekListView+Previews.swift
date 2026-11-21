//
//  ProyekListView+Previews.swift
//  Serona
//

import SwiftData
import SwiftUI

// MARK: - Previews

#Preview("Empty State", traits: .landscapeLeft) {
    NavigationStack {
        ProyekListView()
    }
    .modelContainer(for: SeronaSchema.models, inMemory: true)
}

#Preview("iPad Landscape (3 Stages)", traits: .landscapeLeft) {
    NavigationStack {
        ProyekListView { proyek in
            if proyek.nama == "Bak 3" || proyek.nama == "Bak 5" || proyek.nama == "Bak 6" {
                return ListPreviewMeasurementSource(
                    measurement: ColorMeasurement(visibleAverage: 87, clear: 1000, nir: 100, waterPH: 8)
                )
            }
            return ListPreviewMeasurementSource(
                measurement: ColorMeasurement(visibleAverage: 95, clear: 1000, nir: 100, waterPH: 12)
            )
        }
    }
    .modelContainer(previewGridContainer)
}

#Preview("iPad Portrait (2 Columns)", traits: .portrait) {
    NavigationStack {
        ProyekListView { proyek in
            if proyek.nama == "Bak 3" || proyek.nama == "Bak 5" || proyek.nama == "Bak 6" {
                return ListPreviewMeasurementSource(
                    measurement: ColorMeasurement(visibleAverage: 87, clear: 1000, nir: 100, waterPH: 8)
                )
            }
            return ListPreviewMeasurementSource(
                measurement: ColorMeasurement(visibleAverage: 95, clear: 1000, nir: 100, waterPH: 12)
            )
        }
    }
    .modelContainer(previewGridContainer)
}

private struct ListPreviewMeasurementSource: ColorMeasurementSource {
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

// MARK: - Sample Data Container

@MainActor
private let previewGridContainer: ModelContainer = {
    let container = SeronaSchema.makePreviewContainer()
    let context = container.mainContext

    let resepMaroon = Resep(
        namaWarna: "Merah Maroon", warnaHex: "#7A1C33",
        air: 1000, kepekatan: 80, batasPH: 7
    )
    let resepKrem = Resep(
        namaWarna: "Krem", warnaHex: "#EB9675",
        air: 1000, kepekatan: 80, batasPH: 7
    )
    let resepUnguAbu = Resep(
        namaWarna: "Ungu Abu", warnaHex: "#6B4F69",
        air: 1000, kepekatan: 80, batasPH: 7
    )

    // Bak 1: Stage 1 (Active - Good Quality)
    let bak1 = Proyek(
        nama: "Bak 1",
        perangkatNama: "Bu Fanny",
        resep: resepMaroon,
        jumlahKain: 2,
        tanggal: .now.addingTimeInterval(1)
    )
    bak1.visibleAverageAwal = 100
    bak1.phAwal = 12
    context.insert(bak1)

    // Bak 2: Stage 3 (Inactive / Unscanned)
    let bak2 = Proyek(
        nama: "Bak 2",
        perangkatNama: "ESP 32",
        resep: resepMaroon,
        jumlahKain: 1,
        tanggal: .now.addingTimeInterval(2)
    )
    bak2.selesaikan(kepekatanAkhir: nil, phAkhir: nil)
    context.insert(bak2)

    // Bak 3: Stage 2 (Active Warning)
    let bak3 = Proyek(
        nama: "Bak 3",
        perangkatNama: "Bu Fanny",
        resep: resepKrem,
        jumlahKain: 3,
        tanggal: .now.addingTimeInterval(3)
    )
    bak3.visibleAverageAwal = 100
    bak3.phAwal = 8
    context.insert(bak3)

    // Bak 4: Stage 1 (Active - Good Quality)
    let bak4 = Proyek(
        nama: "Bak 4",
        perangkatNama: "Bu Fanny",
        resep: resepUnguAbu,
        jumlahKain: 2,
        tanggal: .now.addingTimeInterval(4)
    )
    bak4.visibleAverageAwal = 100
    bak4.phAwal = 12
    context.insert(bak4)

    // Bak 5: Stage 2 (Active Warning)
    let bak5 = Proyek(
        nama: "Bak 5",
        perangkatNama: "Bu Fanny",
        resep: resepKrem,
        jumlahKain: 2,
        tanggal: .now.addingTimeInterval(5)
    )
    bak5.visibleAverageAwal = 100
    bak5.phAwal = 8
    context.insert(bak5)

    // Bak 6: Stage 3 (Inactive / Unscanned)
    let bak6 = Proyek(
        nama: "Bak 6",
        perangkatNama: "ESP 32",
        resep: resepKrem,
        jumlahKain: 2,
        tanggal: .now.addingTimeInterval(6)
    )
    bak6.selesaikan(kepekatanAkhir: nil, phAkhir: nil)
    context.insert(bak6)

    return container
}()
