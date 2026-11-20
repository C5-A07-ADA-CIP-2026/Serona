//
//  PengukuranSectionView.swift
//  Serona
//

import SwiftData
import SwiftUI

/// The live readings of a scanned project. The initial color and pH are set from the "awal" rows,
/// right below the "sekarang" row they take their value from. The clean water row comes first: with the probe in
/// clean water it is the reference the color concentration is measured against.
struct PengukuranSectionView: View {
    @ObservedObject var viewModel: ProyekDetailViewModel
    /// Opens the repair guide for what is below its limit; the banner calls it.
    var onPerbaiki: (QualityIssue) -> Void = { _ in }
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            JudulBagian(teks: "Pengukuran")
            if viewModel.isCleanWaterSet || viewModel.canSetCleanWater {
                BarisAwalView(
                    judul: "Air Bersih",
                    nilai: "Tersimpan",
                    isSet: viewModel.isCleanWaterSet,
                    canSet: viewModel.canSetCleanWater,
                    onSet: { umumkan("Air bersih ditetapkan", jika: viewModel.tetapkanAirBersih(in: modelContext)) },
                    onReset: { viewModel.ukurUlangAirBersih(in: modelContext) }
                )
            }
            ForEach(viewModel.measurements.displayedMeasurements) { measurement in
                row(for: measurement)
            }
            if let issue = viewModel.qualityAlert?.issue ?? viewModel.currentIssue {
                LarutanMenurunBanner { onPerbaiki(issue) }
            }
        }
        .sensoryFeedback(.success, trigger: viewModel.isInitialColorSet) { _, isSet in isSet }
        .sensoryFeedback(.success, trigger: viewModel.isInitialPHSet) { _, isSet in isSet }
    }

    @ViewBuilder
    private func row(for measurement: ProyekMeasurement) -> some View {
        switch measurement.id {
        case "initial-color-concentration":
            BarisAwalView(
                judul: measurement.title,
                nilai: measurement.value,
                isSet: viewModel.isInitialColorSet,
                canSet: viewModel.canSetInitialColor,
                onSet: { umumkan("Warna awal ditetapkan", jika: viewModel.tetapkanWarnaAwal(in: modelContext)) },
                onReset: { viewModel.ukurUlangWarnaAwal(in: modelContext) }
            )
        case "initial-water-ph":
            BarisAwalView(
                judul: measurement.title,
                nilai: measurement.value,
                isSet: viewModel.isInitialPHSet,
                canSet: viewModel.canSetInitialPH,
                onSet: { umumkan("pH awal ditetapkan", jika: viewModel.tetapkanPHAwal(in: modelContext)) },
                onReset: { viewModel.ukurUlangPHAwal(in: modelContext) }
            )
        default:
            BarisInfo(
                judul: measurement.title,
                nilai: measurement.value,
                tebal: measurement.isCurrent,
                peringatan: viewModel.isBelowLimit(measurement)
            )
        }
    }

    private func umumkan(_ pesan: String, jika berhasil: Bool) {
        if berhasil {
            AccessibilityNotification.Announcement(pesan).post()
        }
    }
}
