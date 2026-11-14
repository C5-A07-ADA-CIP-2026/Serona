//
//  BakCardView.swift
//  Serona
//
//  Created by Steffany Florence on 10/11/26.
//

import SwiftUI

enum BakCardStage {
    case active
    case activeWarning
    case inactive
}

struct BakCardView: View {
    let proyek: Proyek
    var viewModel: ProyekDetailViewModel?
    var onMulaiPindai: (() -> Void)? = nil
    var onSelesai: (() -> Void)? = nil
    var onPerbaikiLarutan: (() -> Void)? = nil
    var onQualityAlert: ((QualityAlert) -> Void)? = nil

    var body: some View {
        if let viewModel {
            ObservedBakCardBody(
                proyek: proyek,
                viewModel: viewModel,
                onMulaiPindai: onMulaiPindai,
                onSelesai: onSelesai,
                onPerbaikiLarutan: onPerbaikiLarutan,
                onQualityAlert: onQualityAlert
            )
        } else {
            BakCardContent(
                proyek: proyek,
                viewModel: nil,
                onMulaiPindai: onMulaiPindai,
                onSelesai: onSelesai,
                onPerbaikiLarutan: onPerbaikiLarutan
            )
        }
    }
}

private struct ObservedBakCardBody: View {
    let proyek: Proyek
    @ObservedObject var viewModel: ProyekDetailViewModel
    var onMulaiPindai: (() -> Void)?
    var onSelesai: (() -> Void)?
    var onPerbaikiLarutan: (() -> Void)?
    var onQualityAlert: ((QualityAlert) -> Void)?

    private var currentStage: BakCardStage {
        guard proyek.status == .aktif,
              viewModel.isDataScanned,
              viewModel.colorMeasurementError == nil
        else {
            return .inactive
        }

        let isLowConcentration = (viewModel.latestConcentration ?? 100) < ProyekDetailViewModel.defaultConcentrationLimit
        let isLowPH = (viewModel.latestWaterPH ?? 14) < ProyekDetailViewModel.defaultWaterPHLimit
        let hasLiveAlert = viewModel.qualityAlert != nil || viewModel.currentIssue != nil || isLowConcentration || isLowPH
        return hasLiveAlert ? .activeWarning : .active
    }

    var body: some View {
        BakCardContent(
            proyek: proyek,
            viewModel: viewModel,
            onMulaiPindai: onMulaiPindai,
            onSelesai: onSelesai,
            onPerbaikiLarutan: onPerbaikiLarutan
        )
        .onAppear {
            if let existingAlert = viewModel.qualityAlert {
                onQualityAlert?(existingAlert)
            } else if currentStage == .activeWarning {
                onQualityAlert?(makeFallbackAlert())
            }
        }
        .onChange(of: viewModel.qualityAlert) { _, newAlert in
            if let newAlert {
                onQualityAlert?(newAlert)
            }
        }
        .onChange(of: currentStage) { oldStage, newStage in
            if newStage == .activeWarning, oldStage != .activeWarning {
                onQualityAlert?(viewModel.qualityAlert ?? makeFallbackAlert())
            }
        }
    }

    private func makeFallbackAlert() -> QualityAlert {
        let isLowC = (viewModel.latestConcentration ?? 100) < ProyekDetailViewModel.defaultConcentrationLimit
        let isLowPH = (viewModel.latestWaterPH ?? 14) < ProyekDetailViewModel.defaultWaterPHLimit

        let issue: QualityIssue
        let message: String
        switch (isLowC, isLowPH) {
        case (true, true):
            issue = .keduanya
            message = MeasurementWarningTracker.bothMessage
        case (true, false):
            issue = .kepekatan
            message = MeasurementWarningTracker.concentrationMessage(limit: ProyekDetailViewModel.defaultConcentrationLimit)
        case (false, true):
            issue = .phAir
            message = MeasurementWarningTracker.waterPHMessage(limit: ProyekDetailViewModel.defaultWaterPHLimit)
        case (false, false):
            issue = viewModel.currentIssue ?? .keduanya
            message = MeasurementWarningTracker.bothMessage
        }
        return QualityAlert(issue: issue, message: message)
    }
}

private struct BakCardContent: View {
    let proyek: Proyek
    var viewModel: ProyekDetailViewModel?
    var onMulaiPindai: (() -> Void)? = nil
    var onSelesai: (() -> Void)? = nil
    var onPerbaikiLarutan: (() -> Void)? = nil

    // MARK: - Stage & Threshold Resolution

    var stage: BakCardStage {
        guard proyek.status == .aktif,
              let viewModel,
              viewModel.isDataScanned,
              viewModel.colorMeasurementError == nil
        else {
            return .inactive
        }

        let isLowConcentration = (viewModel.latestConcentration ?? 100) < ProyekDetailViewModel.defaultConcentrationLimit
        let isLowPH = (viewModel.latestWaterPH ?? 14) < ProyekDetailViewModel.defaultWaterPHLimit
        let hasLiveAlert = viewModel.qualityAlert != nil || viewModel.currentIssue != nil || isLowConcentration || isLowPH
        return hasLiveAlert ? .activeWarning : .active
    }

    private var isConnected: Bool { stage != .inactive }
    private var isScanning: Bool { viewModel?.isScanning ?? false }

    private var isConcentrationBelowLimit: Bool {
        guard stage != .inactive, let c = viewModel?.latestConcentration else { return false }
        return c < ProyekDetailViewModel.defaultConcentrationLimit
    }

    private var isPHBelowLimit: Bool {
        guard stage != .inactive, let ph = viewModel?.latestWaterPH else { return false }
        return ph < ProyekDetailViewModel.defaultWaterPHLimit
    }

    private var kepekatanDisplay: String {
        guard stage != .inactive, let c = viewModel?.latestConcentration else { return "-" }
        return String(format: "%.0f%%", c)
    }

    private var phDisplay: String {
        guard stage != .inactive, let ph = viewModel?.latestWaterPH else { return "-" }
        return ProyekColorMeasurements.format(ph)
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerRow
            colorInfoRow
            statusBanner
            metricsRow
            actionButton
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: 20))
        .onTapGesture {
            if stage == .activeWarning {
                onPerbaikiLarutan?()
            }
        }
    }

    // MARK: - Card Subviews

    private var headerRow: some View {
        HStack {
            Text(proyek.nama)
                .font(.title2.bold())
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(isConnected ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)

                Text(isConnected ? "Tersambung" : "Tidak Tersambung")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var swatchColor: Color {
        guard stage != .inactive, let hex = proyek.warnaHex else {
            return Color.gray.opacity(0.85)
        }
        return Color(hex: hex)
    }

    private var colorInfoRow: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(swatchColor)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(stage == .inactive ? "-" : proyek.namaWarna)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(stage == .inactive ? "-" : proyek.perangkatNama)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
    }

    private var statusBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: statusIcon)
                .font(.subheadline)

            Text(statusMessage)
                .font(.caption.weight(.semibold))

            Spacer()
        }
        .foregroundStyle(statusForeground)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(statusBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var metricsRow: some View {
        HStack(spacing: 12) {
            statTile(
                icon: "allergens",
                title: "Kepekatan",
                value: kepekatanDisplay,
                isWarning: isConcentrationBelowLimit
            )

            statTile(
                icon: "drop",
                title: "pH Air",
                value: phDisplay,
                isWarning: isPHBelowLimit
            )
        }
    }

    private func statTile(icon: String, title: String, value: String, isWarning: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(Color.black.opacity(0.75))

            Text(value)
                .font(.largeTitle.bold())
                .foregroundStyle(isWarning ? Color(hex: "#DE2428") : .primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(hex: "#F2F2F7").opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var actionButton: some View {
        Button {
            if stage == .inactive {
                onMulaiPindai?()
            } else {
                onSelesai?()
            }
        } label: {
            HStack(spacing: 8) {
                if isScanning {
                    ProgressView()
                        .tint(buttonForeground)
                        .controlSize(.small)
                }
                Text(buttonTitle)
                    .font(.subheadline.bold())
            }
            .foregroundStyle(buttonForeground)
            .padding(.horizontal, 24)
            .frame(height: 44)
            .background(buttonBackground)
            .clipShape(Capsule())
            .shadow(color: buttonShadow, radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(isScanning)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Stage Styling Helpers

    private var buttonBackground: Color {
        switch stage {
        case .active, .activeWarning:
            return .white
        case .inactive:
            return Color.oliveGreen
        }
    }

    private var buttonForeground: Color {
        switch stage {
        case .active:
            return .black
        case .activeWarning:
            return Color(hex: "#DE2428")
        case .inactive:
            return .white
        }
    }

    private var buttonShadow: Color {
        switch stage {
        case .active, .activeWarning:
            return Color.black.opacity(0.12)
        case .inactive:
            return Color.oliveGreen.opacity(0.3)
        }
    }

    private var statusIcon: String {
        switch stage {
        case .active: return "checkmark.circle.fill"
        case .activeWarning: return "exclamationmark.triangle.fill"
        case .inactive: return "questionmark.circle.fill"
        }
    }

    private var statusMessage: String {
        switch stage {
        case .active: return "Kualitas Larutan Baik"
        case .activeWarning: return "Kualitas Larutan Menurun"
        case .inactive: return "Tidak ada data yang terbaca"
        }
    }

    private var statusForeground: Color {
        switch stage {
        case .active: return Color.oliveGreen
        case .activeWarning: return Color(hex: "#DE2428")
        case .inactive: return .secondary
        }
    }

    private var statusBackground: Color {
        switch stage {
        case .active: return Color.oliveGreen.opacity(0.12)
        case .activeWarning: return Color(hex: "#FF4245").opacity(0.12)
        case .inactive: return Color.gray.opacity(0.12)
        }
    }

    private var buttonTitle: String {
        if stage == .inactive {
            return isScanning ? "Memindai..." : "Mulai Pindai"
        }
        return "Selesai"
    }
}

// MARK: - Previews

#Preview("3 Stages Grid (iPad Landscape)", traits: .landscapeLeft) {
    BakCardStagesPreview()
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
                    GridItem(.flexible(), spacing: 20)
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

// MARK: - Preview Helpers

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
