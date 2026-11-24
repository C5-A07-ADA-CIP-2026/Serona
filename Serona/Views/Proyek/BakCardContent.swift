import SwiftUI

struct LiveRevision: Hashable {
    var measuredAt: Date?
    var tick: Date?
}

struct BakCardContent: View {
    let proyek: Proyek
    var viewModel: ProyekDetailViewModel?

    var liveRevision: LiveRevision = .init()
    var onMulaiPindai: (() -> Void)?
    var onSelesai: (() -> Void)?
    var onPerbaikiLarutan: (() -> Void)?

    private var isUsedBak: Bool {
        proyek.status == .aktif
    }

    var stage: BakCardStage {
        guard proyek.status == .aktif else {
            return .inactive
        }

        guard let viewModel else {
            return .disconnected
        }

        let isDisconnected = switch viewModel.connectionState {
        case .disconnected, .failed:
            true
        case .ready, .connecting, .discovering, .reconnecting:
            false
        }

        let hasUnreadyError = viewModel.colorMeasurementError != nil && viewModel.connectionState != .ready
        if !viewModel.isScanning, isDisconnected || hasUnreadyError {
            return .disconnected
        }

        guard viewModel.isDataScanned else {
            return .inactive
        }

        let isLowConcentration = (viewModel.latestConcentration ?? 100) < proyek.batasKepekatan
        let isLowPH = (viewModel.latestWaterPH ?? 14) < proyek.batasPH
        let hasLiveAlert = viewModel.qualityAlert != nil || viewModel.currentIssue != nil
            || isLowConcentration || isLowPH
        return hasLiveAlert ? .activeWarning : .active
    }

    private var isScanning: Bool {
        viewModel?.isScanning ?? false
    }

    private var isConcentrationBelowLimit: Bool {
        guard stage == .active || stage == .activeWarning,
              let concentration = viewModel?.latestConcentration else { return false }
        return concentration < proyek.batasKepekatan
    }

    private var isPHBelowLimit: Bool {
        guard stage == .active || stage == .activeWarning,
              let waterPH = viewModel?.latestWaterPH else { return false }
        return waterPH < proyek.batasPH
    }

    private var kepekatanDisplay: String {
        guard stage == .active || stage == .activeWarning,
              let concentration = viewModel?.latestConcentration else { return "-" }
        return String(format: "%.0f%%", concentration)
    }

    private var phDisplay: String {
        guard stage == .active || stage == .activeWarning,
              let waterPH = viewModel?.latestWaterPH else { return "-" }
        return ProyekColorMeasurements.format(waterPH)
    }

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
        .accessibilityAddTraits(stage == .activeWarning ? .isButton : [])
    }
}

extension BakCardContent {
    private var headerRow: some View {
        let status = connectionStatus
        return ViewThatFits(in: .horizontal) {
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

    private var nameLabel: some View {
        Text(proyek.nama)
            .font(.title2.bold())
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func connectionLabel(_ status: (text: String, dotColor: Color)) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(status.dotColor)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)

            Text(status.text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var connectionStatus: (text: String, dotColor: Color) {
        if proyek.status == .aktif, viewModel?.connectionState == .ready {
            return ("Terhubung", Color(hex: "#34C759"))
        }
        return ("Tidak Terhubung", Color.gray.opacity(0.85))
    }

    private var swatchColor: Color {
        guard isUsedBak, let hex = proyek.warnaHex else {
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
                Text(isUsedBak ? proyek.namaWarna : "-")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(isUsedBak ? proyek.perangkatNama : "-")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
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
            .foregroundStyle(Color.oliveGreenText)

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
            if stage == .inactive || stage == .disconnected {
                onMulaiPindai?()
            } else {
                onSelesai?()
            }
        } label: {
            HStack(spacing: 8) {
                if isScanning {
                    ProgressView()
                        .tint(.white)
                        .controlSize(.small)
                }
                Text(buttonTitle)
                    .font(.subheadline.bold())
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 36)
            .padding(.vertical, 12)
            .frame(minHeight: 44)
            .background(Color.oliveGreen)
            .clipShape(Capsule())
            .shadow(color: Color.oliveGreen.opacity(0.3), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(isScanning)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusIcon: String {
        switch stage {
        case .active: "checkmark.circle.fill"
        case .activeWarning: "exclamationmark.triangle.fill"
        case .inactive, .disconnected: "questionmark.circle.fill"
        }
    }

    private var statusMessage: String {
        switch stage {
        case .active: "Kualitas Larutan Baik"
        case .activeWarning: "Kualitas Larutan Menurun"
        case .inactive, .disconnected: "Tidak ada data yang terbaca"
        }
    }

    private var statusForeground: Color {
        switch stage {
        case .active: Color.oliveGreenText
        case .activeWarning: Color(hex: "#C8191C")
        case .inactive, .disconnected: Color.primary.opacity(0.7)
        }
    }

    private var statusBackground: Color {
        switch stage {
        case .active: Color.oliveGreen.opacity(0.12)
        case .activeWarning: Color(hex: "#FF4245").opacity(0.12)
        case .inactive, .disconnected: Color.gray.opacity(0.12)
        }
    }

    private var buttonTitle: String {
        if stage == .inactive || stage == .disconnected {
            return isScanning ? "Memindai..." : "Mulai Pindai"
        }
        return "Selesai"
    }
}
