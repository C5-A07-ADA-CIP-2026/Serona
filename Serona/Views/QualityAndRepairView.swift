//
//  QualityAndRepairView.swift
//  Serona
//
//  Created by Steffany Florence on 25/11/26.
//

import SwiftUI

// MARK: - Quality Alert Modal

struct QualityAlertModalView: View {
    let bak: DummyBakItem
    let onPerbaiki: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 26) {
                Spacer(minLength: 16)

                ZStack {
                    Circle()
                        .fill(Color(red: 0.99, green: 0.93, blue: 0.93))
                        .frame(width: 210, height: 210)

                    Circle()
                        .fill(Color(red: 0.98, green: 0.87, blue: 0.87))
                        .frame(width: 158, height: 158)

                    Image("BakAlert")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 112, height: 112)
                }

                VStack(spacing: 8) {
                    Text("Kualitas \(bak.nama) Menurun")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.black)
                        .multilineTextAlignment(.center)

                    Text("Lakukan langkah-langkah berikut untuk perbaiki larutan")
                        .font(.subheadline)
                        .foregroundStyle(.black.opacity(0.8))
                        .multilineTextAlignment(.center)
                }

                Button {
                    QualityAlarmPlayer.shared.stop()
                    onPerbaiki()
                } label: {
                    Text("Mulai Perbaiki Larutan")
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(SeronaTheme.oliveGreen, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 44)
                .padding(.top, 4)

                Spacer(minLength: 10)
            }
            .padding(28)
            .frame(width: 520, height: 520)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 32))
            .shadow(color: .black.opacity(0.14), radius: 26, x: 0, y: 12)

            Button {
                QualityAlarmPlayer.shared.stop()
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.black)
                    .frame(width: 40, height: 40)
                    .background(Color.white, in: Circle())
                    .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Tutup")
            .padding(22)
        }
        .onAppear {
            QualityAlarmPlayer.shared.start()
        }
        .onDisappear {
            QualityAlarmPlayer.shared.stop()
        }
    }
}

// MARK: - Perbaiki Larutan 3-Step Centered Modal (Matches Screenshots)

struct PerbaikiLarutanModalView: View {
    let bak: DummyBakItem
    let onDismiss: () -> Void

    @State private var isPHReady: Bool = false
    @State private var isConcentrationReady: Bool = false

    private var currentStepNumber: Int {
        bak.repairGuide.currentStep.rawValue + 1
    }

    private var isNextEnabled: Bool {
        switch bak.repairGuide.currentStep {
        case .air:
            return bak.repairGuide.jumlahAir > 0
        case .phAir:
            return isPHReady
        case .kepekatan:
            return isConcentrationReady
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Top Header: Optional Back (<), "Perbaiki Larutan", Close (×)
            HStack {
                if bak.repairGuide.currentStep != .air {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            goBackStep()
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.black)
                            .frame(width: 40, height: 40)
                            .background(Color.white, in: Circle())
                            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                } else {
                    Color.clear.frame(width: 40, height: 40)
                }

                Spacer()

                Text("Perbaiki Larutan")
                    .font(.headline.bold())
                    .foregroundStyle(.black)

                Spacer()

                Button {
                    // Dismissing keeps bak.repairGuide.currentStep saved
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.black)
                        .frame(width: 40, height: 40)
                        .background(Color.white, in: Circle())
                        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
            }

            // Step Indicator + Title
            VStack(alignment: .leading, spacing: 6) {
                Text("TAHAP \(currentStepNumber) DARI 3")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                Text(stepTitle)
                    .font(.title3.bold())
                    .foregroundStyle(.black)
            }

            // Step Body
            stepContent

            Spacer()

            // Bottom Primary CTA ("Berikutnya" / "Selesai")
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    advanceStep()
                }
            } label: {
                Text(bak.repairGuide.currentStep == .kepekatan ? "Selesai" : "Berikutnya")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                    .frame(width: 300, height: 52)
                    .background(isNextEnabled ? SeronaTheme.oliveGreen : Color.gray.opacity(0.75), in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!isNextEnabled)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.bottom, 6)
        }
        .padding(28)
        .frame(width: 520, height: 610)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 32))
        .shadow(color: .black.opacity(0.14), radius: 26, x: 0, y: 12)
        .onAppear {
            syncStepStateOnAppear()
        }
    }

    private var stepTitle: String {
        switch bak.repairGuide.currentStep {
        case .air: "Tahap 1: Penyesuaian Volume Air Larutan"
        case .phAir: "Tahap 2: Penyesuaian pH Air Larutan"
        case .kepekatan: "Tahap 3: Penyesuaian Kepekatan Warna Larutan"
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch bak.repairGuide.currentStep {
        case .air:
            VStack(alignment: .leading, spacing: 20) {
                Text("Tambahkan air ke dalam wadah untuk menyesuaikan volume dasar larutan.")
                    .font(.subheadline)
                    .foregroundStyle(.black.opacity(0.85))

                HStack {
                    Text("Jumlah Air")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.black)

                    Spacer()

                    HStack(spacing: 4) {
                        TextField("0", value: Binding(
                            get: { bak.repairGuide.jumlahAir },
                            set: { bak.repairGuide.jumlahAir = max(0, $0) }
                        ), format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .font(.subheadline.weight(.medium))
                        .frame(width: 44)

                        Text("Liter")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.black)
                    }
                    .padding(.trailing, 8)

                    HStack(spacing: 0) {
                        Button {
                            if bak.repairGuide.jumlahAir > 0 {
                                bak.repairGuide.jumlahAir -= 1
                            }
                        } label: {
                            Image(systemName: "minus")
                                .font(.subheadline.weight(.semibold))
                                .frame(width: 42, height: 32)
                        }
                        .buttonStyle(.plain)

                        Divider().frame(height: 18)

                        Button {
                            bak.repairGuide.jumlahAir += 1
                        } label: {
                            Image(systemName: "plus")
                                .font(.subheadline.weight(.semibold))
                                .frame(width: 42, height: 32)
                        }
                        .buttonStyle(.plain)
                    }
                    .background(Color.black.opacity(0.05), in: Capsule())
                }
                .padding(.horizontal, 18)
                .frame(height: 54)
                .background(SeronaTheme.modalBackground, in: Capsule())
            }

        case .phAir:
            let sodaGram = max(15, bak.repairGuide.jumlahAir * 15)
            let displayedPH = isPHReady ? 12 : Int(bak.phAir)

            VStack(alignment: .leading, spacing: 14) {
                // Pill 1: Tambahkan Soda Abu
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Tambahkan Soda Abu")
                            .font(.subheadline.bold())
                            .foregroundStyle(.black)
                        Text("Larutkan dengan air panas secukupnya.")
                            .font(.caption)
                            .foregroundStyle(.black.opacity(0.8))
                    }
                    Spacer()
                    Text("\(sodaGram) gr")
                        .font(.subheadline.bold())
                        .foregroundStyle(.black)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(SeronaTheme.modalBackground, in: RoundedRectangle(cornerRadius: 20))

                // Pill 2: Target level pH
                HStack {
                    Text("Target level pH")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.black)
                    Spacer()
                    Text("12")
                        .font(.subheadline.bold())
                        .foregroundStyle(.black)
                }
                .padding(.horizontal, 20)
                .frame(height: 50)
                .background(SeronaTheme.modalBackground, in: Capsule())

                // Pill 3: Level pH sekarang (Red warning -> Green verified)
                HStack {
                    Text("Level pH sekarang")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.black)
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: isPHReady ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.subheadline)
                        Text("\(displayedPH)")
                            .font(.subheadline.bold())
                    }
                    .foregroundStyle(isPHReady ? Color(red: 0.20, green: 0.68, blue: 0.25) : SeronaTheme.warningRed)
                }
                .padding(.horizontal, 20)
                .frame(height: 50)
                .background(
                    Capsule()
                        .fill(isPHReady ? Color(red: 0.93, green: 0.98, blue: 0.93) : Color.white)
                )
                .overlay(
                    Capsule()
                        .stroke(isPHReady ? Color.clear : SeronaTheme.warningRed.opacity(0.65), lineWidth: 1.2)
                )
                .contentShape(Capsule())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isPHReady = true
                        bak.phAir = 12.0
                    }
                }

                Text("Tunggu beberapa saat agar larutan air mencapai target level pH semula.")
                    .font(.caption)
                    .foregroundStyle(.black.opacity(0.75))
                    .padding(.top, 2)
            }

        case .kepekatan:
            let dyeGram = max(15, bak.repairGuide.jumlahAir * 15)
            let displayedConcentration = isConcentrationReady ? 100 : bak.kepekatan

            VStack(alignment: .leading, spacing: 14) {
                // Pill 1: Tambahkan Naphthol AS / Pewarna
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Tambahkan \(bak.kodePewarna)")
                            .font(.subheadline.bold())
                            .foregroundStyle(.black)
                        Text("Larutkan dengan air panas secukupnya.")
                            .font(.caption)
                            .foregroundStyle(.black.opacity(0.8))
                    }
                    Spacer()
                    Text("\(dyeGram) gr")
                        .font(.subheadline.bold())
                        .foregroundStyle(.black)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(SeronaTheme.modalBackground, in: RoundedRectangle(cornerRadius: 20))

                // Pill 2: Target kepekatan warna
                HStack {
                    Text("Target kepekatan warna")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.black)
                    Spacer()
                    Text("100%")
                        .font(.subheadline.bold())
                        .foregroundStyle(.black)
                }
                .padding(.horizontal, 20)
                .frame(height: 50)
                .background(SeronaTheme.modalBackground, in: Capsule())

                // Pill 3: Kepekatan warna sekarang (Red warning -> Green verified)
                HStack {
                    Text("Kepekatan warna sekarang")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.black)
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: isConcentrationReady ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.subheadline)
                        Text("\(displayedConcentration)%")
                            .font(.subheadline.bold())
                    }
                    .foregroundStyle(isConcentrationReady ? Color(red: 0.20, green: 0.68, blue: 0.25) : SeronaTheme.warningRed)
                }
                .padding(.horizontal, 20)
                .frame(height: 50)
                .background(
                    Capsule()
                        .fill(isConcentrationReady ? Color(red: 0.93, green: 0.98, blue: 0.93) : Color.white)
                )
                .overlay(
                    Capsule()
                        .stroke(isConcentrationReady ? Color.clear : SeronaTheme.warningRed.opacity(0.65), lineWidth: 1.2)
                )
                .contentShape(Capsule())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isConcentrationReady = true
                        bak.kepekatan = 100
                    }
                }

                Text("Tunggu beberapa saat agar larutan air mencapai target kepekatan warna semula.")
                    .font(.caption)
                    .foregroundStyle(.black.opacity(0.75))
                    .padding(.top, 2)
            }
        }
    }

    // MARK: - Step Transitions & Dummy Sensor Stabilization

    private func syncStepStateOnAppear() {
        switch bak.repairGuide.currentStep {
        case .air:
            break
        case .phAir:
            isPHReady = bak.phAir >= 12.0
            if !isPHReady { scheduleDummyPHStabilization() }
        case .kepekatan:
            isConcentrationReady = bak.kepekatan >= 100
            if !isConcentrationReady { scheduleDummyConcentrationStabilization() }
        }
    }

    private func goBackStep() {
        switch bak.repairGuide.currentStep {
        case .air:
            break
        case .phAir:
            bak.repairGuide.currentStep = .air
        case .kepekatan:
            bak.repairGuide.currentStep = .phAir
            isPHReady = true
        }
    }

    private func advanceStep() {
        switch bak.repairGuide.currentStep {
        case .air:
            bak.repairGuide.currentStep = .phAir
            isPHReady = bak.phAir >= 12.0
            if !isPHReady {
                scheduleDummyPHStabilization()
            }
        case .phAir:
            bak.phAir = 12.0
            bak.repairGuide.currentStep = .kepekatan
            isConcentrationReady = bak.kepekatan >= 100
            if !isConcentrationReady {
                scheduleDummyConcentrationStabilization()
            }
        case .kepekatan:
            bak.kepekatan = 100
            bak.phAir = 12.0
            bak.hasShownAutoAlert = false
            bak.repairGuide.reset()
            onDismiss()
        }
    }

    private func scheduleDummyPHStabilization() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            guard bak.repairGuide.currentStep == .phAir, !isPHReady else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                isPHReady = true
                bak.phAir = 12.0
            }
        }
    }

    private func scheduleDummyConcentrationStabilization() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            guard bak.repairGuide.currentStep == .kepekatan, !isConcentrationReady else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                isConcentrationReady = true
                bak.kepekatan = 100
            }
        }
    }
}
