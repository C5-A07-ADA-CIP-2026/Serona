import SwiftUI

struct PerbaikiLarutanView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @State var guide: PerbaikiLarutanViewModel
    @ObservedObject var viewModel: ProyekDetailViewModel

    var onClose: (() -> Void)? = nil

    @ScaledMetric(relativeTo: .body) var closeButtonSize: CGFloat = 40
    @ScaledMetric(relativeTo: .body) var numericFieldWidth: CGFloat = 68

    let alertRed = Color(hex: "#DE2428")
    let successGreen = Color(hex: "#28A745")
    let pillBackground = Color(red: 0.95, green: 0.95, blue: 0.97)

    init(
        issue: QualityIssue,
        viewModel: ProyekDetailViewModel,
        initialStep: PerbaikiStep? = nil,
        initialJumlahAir: Int? = nil,
        onClose: (() -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.onClose = onClose
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
        guideContent
            .frame(width: 520, height: 610)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 32))
            .shadow(color: Color.black.opacity(0.14), radius: 26, x: 0, y: 12)
            .presentationBackground(.clear)
            .interactiveDismissDisabled()
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
                    closeModal()
                }
            }
    }

    func closeModal() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }
}

extension PerbaikiLarutanView {
    var guideContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                if guide.currentStep != .air {
                    backButton
                } else {
                    Color.clear
                        .frame(width: closeButtonSize, height: closeButtonSize)
                }

                Spacer()

                Text("Perbaiki Larutan")
                    .font(.headline.bold())
                    .foregroundStyle(.black)
                    .multilineTextAlignment(.center)

                Spacer()

                closeButton
            }

            stepContent

            Spacer()

            nextButton
        }
        .padding(.horizontal, 28)
        .padding(.top, 24)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    var backButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                let previousStep: PerbaikiStep = (guide.currentStep == .kepekatan) ? .phAir : .air
                guide = PerbaikiLarutanViewModel(
                    issue: viewModel.qualityAlert?.issue ?? .keduanya,
                    proyek: viewModel.proyek,
                    pHSebelum: viewModel.latestWaterPH,
                    initialStep: previousStep,
                    initialJumlahAir: guide.jumlahAir
                )
            }
        } label: {
            Image(systemName: "chevron.left")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.black)
                .frame(width: closeButtonSize, height: closeButtonSize)
                .background(Color.white, in: Circle())
                .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Kembali")
    }

    var nextButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                guide.lanjut(waterPH: viewModel.latestWaterPH)
            }
        } label: {
            Text(guide.buttonTitle(for: guide.currentStep))
                .font(.headline.bold())
                .foregroundStyle(.white)
                .frame(width: 300, height: 52)
                .background(
                    canProceed ? Color.oliveGreen : Color.gray.opacity(0.75),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
        .disabled(!canProceed)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    var closeButton: some View {
        Button {
            closeModal()
        } label: {
            Image(systemName: "xmark")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.black)
                .frame(width: closeButtonSize, height: closeButtonSize)
                .background(Color.white, in: Circle())
                .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Tutup")
    }

    var concentrationStatusSymbol: String {
        isConcentrationReached ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
    }

    var formattedCurrentPH: String {
        guard let waterPH = viewModel.latestWaterPH else { return "-" }
        return ProyekColorMeasurements.format(waterPH)
    }

    var formattedCurrentConcentration: String {
        guard let conc = viewModel.latestConcentration else { return "-" }
        return String(format: "%.0f%%", min(conc, 100))
    }

    func formatGram(_ gram: Double) -> String {
        let rounded = gram.rounded(.up)
        return String(format: "%.0f gr", rounded)
    }
}
