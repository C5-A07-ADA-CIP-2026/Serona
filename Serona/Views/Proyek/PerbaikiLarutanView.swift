//
//  PerbaikiLarutanView.swift
//  Serona
//

import SwiftUI

struct PerbaikiLarutanView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var guide: PerbaikiLarutanViewModel
    @ObservedObject var viewModel: ProyekDetailViewModel

    @ScaledMetric(relativeTo: .body) private var sheetIdealWidth: CGFloat = 440
    @ScaledMetric(relativeTo: .body) private var closeButtonSize: CGFloat = 38
    @ScaledMetric(relativeTo: .body) private var numericFieldWidth: CGFloat = 68

    private let alertRed = Color(hex: "#DE2428")
    private let successGreen = Color(hex: "#28A745")

    init(
        issue: QualityIssue,
        viewModel: ProyekDetailViewModel,
        initialStep: PerbaikiStep = .air,
        initialJumlahAir: Int = 0
    ) {
        _guide = State(wrappedValue: PerbaikiLarutanViewModel(
            issue: issue,
            proyek: viewModel.proyek,
            pHSebelum: viewModel.latestWaterPH,
            initialStep: initialStep,
            initialJumlahAir: initialJumlahAir
        ))
        self.viewModel = viewModel
    }

    private var headerTitle: String {
        let warna = viewModel.proyek.namaWarna.trimmingCharacters(in: .whitespacesAndNewlines)
        if !warna.isEmpty && warna != "-" {
            return warna
        }
        return viewModel.proyek.nama
    }

    private var isPHReached: Bool {
        guard let currentPH = viewModel.latestWaterPH else { return false }
        return currentPH >= PerbaikiLarutanViewModel.targetPH
    }

    private var isConcentrationReached: Bool {
        guard let currentConc = viewModel.latestConcentration else { return false }
        return currentConc >= PerbaikiLarutanViewModel.targetConcentration
    }

    private var canProceed: Bool {
        guide.canProceed(
            currentPH: viewModel.latestWaterPH,
            currentConcentration: viewModel.latestConcentration
        )
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 20) {
                Text(headerTitle)
                    .font(.headline.bold())
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)

                Text(
                    "Ikuti panduan penambahan bahan di bawah ini untuk mengembalikan kualitas larutan sesuai threshold."
                )
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

                stepContent

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        guide.lanjut(waterPH: viewModel.latestWaterPH)
                    }
                } label: {
                    Text("Selanjutnya")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            canProceed ? Color.oliveGreen : Color.gray.opacity(0.75),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canProceed)
                .padding(.top, 4)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 28)
            .frame(minWidth: 340, idealWidth: sheetIdealWidth, maxWidth: 480)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(width: closeButtonSize, height: closeButtonSize)
                    .background(Color.white, in: Circle())
                    .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Tutup")
            .padding(20)
        }
        .background(Color.white)
        .presentationSizing(.fitted)
        .presentationBackground(Color.white)
        .presentationDragIndicator(.hidden)
        .onChange(of: viewModel.qualityAlert) { _, alert in
            if let alert {
                guide.updateIssue(alert.issue)
            }
        }
        .onChange(of: viewModel.latestWaterPH) { _, newPH in
            guide.syncPHBeforeWater(newPH)
        }
        .onChange(of: guide.isFinished) { _, isFinished in
            if isFinished {
                viewModel.clearQualityAlert()
                dismiss()
            }
        }
    }

    // MARK: - Step Views

    @ViewBuilder
    private var stepContent: some View {
        switch guide.currentStep {
        case .air:
            tahap1VolumeAirView
        case .phAir:
            tahap2PHView
        case .kepekatan:
            tahap3KepekatanView
        }
    }

    private var tahap1VolumeAirView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Tahap 1: Penyesuaian Volume Air Larutan")
                .font(.title2.bold())
                .foregroundStyle(Color.oliveGreen)
                .fixedSize(horizontal: false, vertical: true)

            Text("Tambahkan air ke dalam wadah untuk menyesuaikan volume dasar larutan.")
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Text("Tambahkan Air")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)

                TextField("0", value: $guide.jumlahAir, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.subheadline.weight(.medium))
                    .monospacedDigit()
                    .textFieldStyle(.roundedBorder)
                    .frame(width: numericFieldWidth)
                    .onChange(of: guide.jumlahAir) { _, newValue in
                        if newValue < 0 {
                            guide.jumlahAir = 0
                        }
                    }

                Text("L")
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                Spacer()

                Stepper("Jumlah air", value: $guide.jumlahAir, in: 0 ... 999)
                    .labelsHidden()
            }
            .padding(.top, 4)
        }
    }

    private var tahap2PHView: some View {
        let additions = guide.sodaAdditions(currentPH: viewModel.latestWaterPH)

        return VStack(alignment: .leading, spacing: 16) {
            Text("Tahap 2: Penyesuaian pH Air Larutan")
                .font(.title2.bold())
                .foregroundStyle(Color.oliveGreen)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(additions, id: \.kode) { item in
                    Text("Tambahkan \(item.kode) sebanyak\n\(formatGram(item.gram))")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.oliveGreen.opacity(0.12), in: .rect(cornerRadius: 14, style: .continuous))

            VStack(spacing: 12) {
                HStack {
                    Text("Target level pH")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("12")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                }

                HStack {
                    Text("Level pH sekarang")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: isPHReached ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.subheadline)
                        Text(formattedCurrentPH)
                            .font(.subheadline.bold())
                    }
                    .foregroundStyle(isPHReached ? successGreen : alertRed)
                }
            }

            Divider()

            Text("Tunggu beberapa saat agar larutan air mencapai target pH semula.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var tahap3KepekatanView: some View {
        let additions = guide.pewarnaAdditions(currentConcentration: viewModel.latestConcentration)

        return VStack(alignment: .leading, spacing: 16) {
            Text("Tahap 3: Penyesuaian Kepekatan Warna Larutan")
                .font(.title2.bold())
                .foregroundStyle(Color.oliveGreen)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(additions, id: \.kode) { item in
                    Text("Tambahkan \(item.kode) sebanyak\n\(formatGram(item.gram))")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.oliveGreen.opacity(0.12), in: .rect(cornerRadius: 14, style: .continuous))

            VStack(spacing: 12) {
                HStack {
                    Text("Target kepekatan warna")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("100%")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                }

                HStack {
                    Text("Kepekatan warna sekarang")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: isConcentrationReached ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.subheadline)
                        Text(formattedCurrentConcentration)
                            .font(.subheadline.bold())
                    }
                    .foregroundStyle(isConcentrationReached ? successGreen : alertRed)
                }
            }

            Divider()

            Text("Tunggu beberapa saat agar larutan air mencapai target kepekatan warna semula.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Formatting

    private var formattedCurrentPH: String {
        guard let ph = viewModel.latestWaterPH else { return "-" }
        return ProyekColorMeasurements.format(ph)
    }

    private var formattedCurrentConcentration: String {
        guard let conc = viewModel.latestConcentration else { return "-" }
        return String(format: "%.0f%%", conc)
    }

    private func formatGram(_ gram: Double) -> String {
        let rounded = gram.rounded(.up)
        return String(format: "%.0f gr", rounded)
    }
}

// MARK: - Previews

#Preview("Tahap 1: Volume Air (0 L)", traits: .landscapeLeft) {
    PerbaikiLarutanStepPreview(
        previewID: "step1-0L",
        step: .air,
        jumlahAir: 0,
        visibleAverage: 72,
        waterPH: 8
    )
}

#Preview("Tahap 1: Volume Air (2 L)", traits: .landscapeLeft) {
    PerbaikiLarutanStepPreview(
        previewID: "step1-2L",
        step: .air,
        jumlahAir: 2,
        visibleAverage: 72,
        waterPH: 8
    )
}

#Preview("Tahap 2: pH Air (pH 8)", traits: .landscapeLeft) {
    PerbaikiLarutanStepPreview(
        previewID: "step2-ph8",
        step: .phAir,
        jumlahAir: 2,
        visibleAverage: 72,
        waterPH: 8
    )
}

#Preview("Tahap 2: pH Air (Target 12)", traits: .landscapeLeft) {
    PerbaikiLarutanStepPreview(
        previewID: "step2-ph12",
        step: .phAir,
        jumlahAir: 2,
        visibleAverage: 72,
        waterPH: 12
    )
}

#Preview("Tahap 3: Kepekatan (72%)", traits: .landscapeLeft) {
    PerbaikiLarutanStepPreview(
        previewID: "step3-72",
        step: .kepekatan,
        jumlahAir: 2,
        visibleAverage: 72,
        waterPH: 12
    )
}

#Preview("Tahap 3: Kepekatan (Target 100%)", traits: .landscapeLeft) {
    PerbaikiLarutanStepPreview(
        previewID: "step3-100",
        step: .kepekatan,
        jumlahAir: 2,
        visibleAverage: 100,
        waterPH: 12
    )
}

// MARK: - Preview Helpers

private struct PerbaikiLarutanStepPreview: View {
    let previewID: String
    let step: PerbaikiStep
    let jumlahAir: Int
    @StateObject private var vm: ProyekDetailViewModel

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
        _vm = StateObject(wrappedValue: ProyekDetailViewModel(
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
            Color.black.opacity(0.25)
                .ignoresSafeArea()

            PerbaikiLarutanView(
                issue: .keduanya,
                viewModel: vm,
                initialStep: step,
                initialJumlahAir: jumlahAir
            )
            .clipShape(.rect(cornerRadius: 24, style: .continuous))
            .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
        }
        .id(previewID)
        .task(id: previewID) {
            await vm.mulaiPindai()
        }
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
                air: 5000,
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
