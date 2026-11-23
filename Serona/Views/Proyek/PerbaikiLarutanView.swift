//
//  PerbaikiLarutanView.swift
//  Serona
//

import SwiftUI

struct PerbaikiLarutanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var guide: PerbaikiLarutanViewModel
    @ObservedObject var viewModel: ProyekDetailViewModel

    @ScaledMetric(relativeTo: .body) private var closeButtonSize: CGFloat = 38
    @ScaledMetric(relativeTo: .body) private var numericFieldWidth: CGFloat = 68

    private let alertRed = Color(hex: "#DE2428")
    private let successGreen = Color(hex: "#28A745")

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

    private var guideContent: some View {
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

    private var nextButton: some View {
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

    private var closeButton: some View {
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
            VStack(alignment: .leading, spacing: 0) {
                Text(
                    "TAHAP 1 DARI 3"
                )
                .font(.caption)
                .foregroundStyle(.black)
                .fixedSize(horizontal: false, vertical: true)
                
                Text("Tahap 1: Penyesuaian Volume Air Larutan")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("Tambahkan air ke dalam wadah untuk menyesuaikan volume dasar larutan.")
                .font(.body)
                .foregroundStyle(Color.black)
                .fixedSize(horizontal: false, vertical: true)

            // At accessibility sizes the label gets its own line so it is not squeezed into broken words.
            let rowLayout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                : AnyLayout(HStackLayout(spacing: 12))

            rowLayout {
                Text("Jumlah Air")
                    .font(.body)
                    .foregroundStyle(.primary)

                if !dynamicTypeSize.isAccessibilitySize {
                    Spacer(minLength: 8)
                }
                
                HStack(spacing: 12) {
                    Text("\(guide.jumlahAir) Liter")
                        .font(.body)
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                    
                    Stepper("Jumlah air", value: $guide.jumlahAir, in: 0 ... 999)
                        .labelsHidden()
                        .onChange(of: guide.jumlahAir) { _, newValue in
                            if newValue < 0 {
                                guide.jumlahAir = 0
                            }
                        }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6), in: .capsule)
        }
    }

    private var tahap2PHView: some View {
        let additions = guide.sodaAdditions(currentPH: viewModel.latestWaterPH)

        return VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(
                    "TAHAP 2 DARI 3"
                )
                .font(.caption)
                .foregroundStyle(.black)
                .fixedSize(horizontal: false, vertical: true)
                
                Text("Tahap 2: Penyesuaian pH Air Larutan")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(additions, id: \.kode) { item in
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Tambahkan \(item.kode) sebanyak \(formatGram(item.gram))")
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Text("Larutkan dengan air panas secukupnya.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        Spacer()
                        
                        Text(formatGram(item.gram))
                            .font(.headline)
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6), in: .rect(cornerRadius: 24, style: .continuous))
            
            HStack {
                Text("Target level pH")
                    .font(.body)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Text("12")
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6), in: .capsule)
            
            HStack {
                Text("Level pH sekarang")
                    .font(.body)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                HStack(spacing: 6) {
                    Image(systemName: isPHReached ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.subheadline)
                    Text(formattedCurrentPH)
                        .font(.body.weight(.semibold))
                        .monospacedDigit()
                }
                .foregroundStyle(isPHReached ? Color.green : Color.red)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isPHReached ? Color.green.opacity(0.08) : Color.red.opacity(0.08),
                in: .capsule
            )
            .overlay {
                Capsule()
                    .stroke(
                        isPHReached ? Color.green.opacity(0.75) : Color.red.opacity(0.75),
                        lineWidth: 1.2
                    )
            }

            Text("Tunggu beberapa saat agar larutan air mencapai target kepekatan warna semula.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)
        }
    }

    private var tahap3KepekatanView: some View {
        let additions = guide.pewarnaAdditions(currentConcentration: viewModel.latestConcentration)
        let isReached = isConcentrationReached

        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(
                    "TAHAP 3 DARI 3"
                )
                .font(.caption)
                .foregroundStyle(.black)
                .fixedSize(horizontal: false, vertical: true)
                
                Text("Tahap 3: Penyesuaian Kepekatan Warna Larutan")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(additions, id: \.kode) { item in
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Tambahkan \(item.kode)")
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Text("Larutkan dengan air panas secukupnya.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        Spacer()
                        
                        Text(formatGram(item.gram))
                            .font(.headline)
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6), in: .rect(cornerRadius: 24, style: .continuous))

            HStack {
                Text("Target kepekatan warna")
                    .font(.body)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Text("100%")
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6), in: .capsule)
            
            HStack {
                Text("Kepekatan warna sekarang")
                    .font(.body)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                HStack(spacing: 6) {
                    Image(systemName: isReached ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.subheadline)
                    Text(formattedCurrentConcentration)
                        .font(.body.weight(.semibold))
                        .monospacedDigit()
                }
                .foregroundStyle(isReached ? Color.green : Color.red)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isReached ? Color.green.opacity(0.08) : Color.red.opacity(0.08),
                in: .capsule
            )
            .overlay {
                Capsule()
                    .stroke(
                        isReached ? Color.green.opacity(0.75) : Color.red.opacity(0.75),
                        lineWidth: 1.2
                    )
            }

            Text("Tunggu beberapa saat agar larutan air mencapai target kepekatan warna semula.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)
        }
    }

    // MARK: - Formatting

    private var concentrationStatusSymbol: String {
        isConcentrationReached ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
    }

    private var formattedCurrentPH: String {
        guard let waterPH = viewModel.latestWaterPH else { return "-" }
        return ProyekColorMeasurements.format(waterPH)
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
