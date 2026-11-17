//
//  BakCardContent.swift
//  Serona
//

import SwiftUI

struct BakCardContent: View {
    let proyek: Proyek
    var viewModel: ProyekDetailViewModel?
    var onMulaiPindai: (() -> Void)?
    var onSelesai: (() -> Void)?
    var onPerbaikiLarutan: (() -> Void)?

    // MARK: - Stage & Threshold Resolution

    var stage: BakCardStage {
        guard proyek.status == .aktif,
              let viewModel,
              viewModel.isDataScanned,
              viewModel.colorMeasurementError == nil
        else {
            return .inactive
        }

        let isLowConcentration = (viewModel.latestConcentration ?? 100) < proyek.batasKepekatan
        let isLowPH = (viewModel.latestWaterPH ?? 14) < proyek.batasPH
        let hasLiveAlert = viewModel.qualityAlert != nil || viewModel.currentIssue != nil
            || isLowConcentration || isLowPH
        return hasLiveAlert ? .activeWarning : .active
    }

    private var isConnected: Bool {
        viewModel?.connectionState == .ready
    }

    private var isScanning: Bool {
        viewModel?.isScanning ?? false
    }

    private var isConcentrationBelowLimit: Bool {
        guard stage != .inactive, let concentration = viewModel?.latestConcentration else { return false }
        return concentration < proyek.batasKepekatan
    }

    private var isPHBelowLimit: Bool {
        guard stage != .inactive, let waterPH = viewModel?.latestWaterPH else { return false }
        return waterPH < proyek.batasPH
    }

    private var kepekatanDisplay: String {
        guard stage != .inactive, let concentration = viewModel?.latestConcentration else { return "-" }
        return String(format: "%.0f%%", concentration)
    }

    private var phDisplay: String {
        guard stage != .inactive, let waterPH = viewModel?.latestWaterPH else { return "-" }
        return ProyekColorMeasurements.format(waterPH)
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
}

extension BakCardContent {
    // MARK: - Card Subviews

    private var headerRow: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let status = connectionStatus(at: context.date)
            // The status moves under the name when both do not fit on one line (a narrow card or large text).
            ViewThatFits(in: .horizontal) {
                HStack {
                    nameLabel
                    Spacer()
                    connectionLabel(status)
                }

                VStack(alignment: .leading, spacing: 6) {
                    nameLabel
                    connectionLabel(status)
                }
            }
        }
    }

    private var nameLabel: some View {
        Text(proyek.nama)
            .font(.title2.bold())
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func connectionLabel(_ status: (text: String, icon: String)) -> some View {
        HStack(spacing: 6) {
            Image(systemName: status.icon)
                .accessibilityHidden(true)

            Text(status.text)
                .font(.caption)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func connectionStatus(at date: Date) -> (text: String, icon: String) {
        guard let viewModel else { return ("Tidak tersambung", "antenna.radiowaves.left.and.right.slash") }
        switch viewModel.connectionState {
        case .ready:
            return viewModel.isMeasurementStale(at: date)
                ? ("Data sensor lama", "clock.badge.exclamationmark")
                : ("Tersambung", "antenna.radiowaves.left.and.right")
        case .connecting, .discovering:
            return ("Menyambungkan", "antenna.radiowaves.left.and.right")
        case .reconnecting:
            return ("Menyambungkan ulang", "arrow.clockwise")
        case .failed:
            return ("Koneksi gagal", "exclamationmark.triangle")
        case .disconnected:
            return ("Tidak tersambung", "antenna.radiowaves.left.and.right.slash")
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
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                concentrationTile
                phTile
            }
            VStack(spacing: 12) {
                concentrationTile
                phTile
            }
        }
    }

    private var concentrationTile: some View {
        statTile(
            icon: "allergens",
            title: "Kepekatan",
            value: kepekatanDisplay,
            isWarning: isConcentrationBelowLimit
        )
    }

    private var phTile: some View {
        statTile(
            icon: "drop",
            title: "pH Air",
            value: phDisplay,
            isWarning: isPHBelowLimit
        )
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
            .padding(.vertical, 12)
            .frame(minHeight: 44)
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
            .white
        case .inactive:
            Color.oliveGreen
        }
    }

    private var buttonForeground: Color {
        switch stage {
        case .active:
            .black
        case .activeWarning:
            Color(hex: "#DE2428")
        case .inactive:
            .white
        }
    }

    private var buttonShadow: Color {
        switch stage {
        case .active, .activeWarning:
            Color.black.opacity(0.12)
        case .inactive:
            Color.oliveGreen.opacity(0.3)
        }
    }

    private var statusIcon: String {
        switch stage {
        case .active: "checkmark.circle.fill"
        case .activeWarning: "exclamationmark.triangle.fill"
        case .inactive: "questionmark.circle.fill"
        }
    }

    private var statusMessage: String {
        switch stage {
        case .active: "Kualitas Larutan Baik"
        case .activeWarning: "Kualitas Larutan Menurun"
        case .inactive: "Tidak ada data yang terbaca"
        }
    }

    private var statusForeground: Color {
        switch stage {
        case .active: Color.oliveGreen
        case .activeWarning: Color(hex: "#DE2428")
        case .inactive: .secondary
        }
    }

    private var statusBackground: Color {
        switch stage {
        case .active: Color.oliveGreen.opacity(0.12)
        case .activeWarning: Color(hex: "#FF4245").opacity(0.12)
        case .inactive: Color.gray.opacity(0.12)
        }
    }

    private var buttonTitle: String {
        if stage == .inactive {
            return isScanning ? "Memindai..." : "Mulai Pindai"
        }
        return "Selesai"
    }
}
