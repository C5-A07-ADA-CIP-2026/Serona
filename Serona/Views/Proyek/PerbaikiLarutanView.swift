//
//  PerbaikiLarutanView.swift
//  Serona
//

import SwiftUI

struct PerbaikiLarutanView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @State var guide: PerbaikiLarutanViewModel
    @ObservedObject var viewModel: ProyekDetailViewModel

    @ScaledMetric(relativeTo: .body) var closeButtonSize: CGFloat = 38
    @ScaledMetric(relativeTo: .body) var numericFieldWidth: CGFloat = 68

    let alertRed = Color(hex: "#DE2428")
    let successGreen = Color(hex: "#28A745")

    init(
        issue: QualityIssue,
        viewModel: ProyekDetailViewModel,
        initialStep: PerbaikiStep? = nil,
        initialJumlahAir: Int? = nil
    ) {
        self.viewModel = viewModel
        if initialStep != nil || initialJumlahAir != nil {
            _guide = State(wrappedValue: PerbaikiLarutanViewModel(
                issue: issue,
                proyek: viewModel.proyek,
                pHSebelum: viewModel.latestWaterPH,
                initialStep: initialStep ?? .air,
                initialJumlahAir: initialJumlahAir ?? 0
            ))
        } else {
            _guide = State(wrappedValue: viewModel.repairGuide(for: issue))
        }
    }

//    private var headerTitle: String {
//        let warna = viewModel.proyek.namaWarna.trimmingCharacters(in: .whitespacesAndNewlines)
//        if !warna.isEmpty, warna != "-" {
//            return warna
//        }
//        return viewModel.proyek.nama
//    }

    var isPHReached: Bool {
        guard let currentPH = viewModel.latestWaterPH else { return false }
        return currentPH >= PerbaikiLarutanViewModel.targetPH
    }

    var isConcentrationReached: Bool {
        guard let currentConc = viewModel.latestConcentration else { return false }
        return currentConc >= PerbaikiLarutanViewModel.targetConcentration
    }

    var canProceed: Bool {
        guide.canProceed(
            currentPH: viewModel.latestWaterPH,
            currentConcentration: viewModel.latestConcentration
        )
    }

    var body: some View {
        GeometryReader { proxy in
            // Fill the current detent height so content stays at the top and the button stays at the bottom,
            // while scrolling smoothly when resized to a shorter detent or larger Dynamic Type.
            ScrollView {
                guideContent
                    .frame(minHeight: proxy.size.height, alignment: .top)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(Color.white)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationContentInteraction(.scrolls)
        .presentationBackground(Color.white)
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
                viewModel.clearRepairGuide()
                viewModel.clearQualityAlert()
                dismiss()
            }
        }
    }
}

extension PerbaikiLarutanView {
    // MARK: - Layout

    var guideContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            // The close button lives in the title row, so it scrolls with the content instead of covering it.
            ZStack(alignment: .trailing) {
                Text("Perbaiki Larutan")
                    .font(.headline.bold())
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, closeButtonSize + 8)

                closeButton
            }

//            Text(
//                "Ikuti panduan penambahan bahan di bawah ini untuk mengembalikan kualitas larutan sesuai threshold."
//            )
//            .font(.subheadline)
//            .foregroundStyle(.primary)
//            .fixedSize(horizontal: false, vertical: true)

            stepContent

            Spacer(minLength: 20)

            nextButton
        }
        .padding(.horizontal, 28)
        .padding(.top, 24)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity)
    }

    var nextButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                guide.lanjut(waterPH: viewModel.latestWaterPH)
            }
        } label: {
            Text(guide.buttonTitle(for: guide.currentStep))
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
    }

    var closeButton: some View {
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
    }

    // MARK: - Formatting

    var concentrationStatusSymbol: String {
        isConcentrationReached ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
    }

    var formattedCurrentPH: String {
        guard let waterPH = viewModel.latestWaterPH else { return "-" }
        return ProyekColorMeasurements.format(waterPH)
    }

    var formattedCurrentConcentration: String {
        guard let conc = viewModel.latestConcentration else { return "-" }
        return String(format: "%.0f%%", conc)
    }

    func formatGram(_ gram: Double) -> String {
        let rounded = gram.rounded(.up)
        return String(format: "%.0f gr", rounded)
    }
}
