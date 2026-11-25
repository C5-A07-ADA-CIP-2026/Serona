import SwiftUI

extension PerbaikiLarutanView {
    @ViewBuilder
    var stepContent: some View {
        switch guide.currentStep {
        case .air:
            tahap1VolumeAirView
        case .phAir:
            tahap2PHView
        case .kepekatan:
            tahap3KepekatanView
        }
    }

    var tahap1VolumeAirView: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("TAHAP 1 DARI 3")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Tahap 1: Penyesuaian Volume Air Larutan")
                    .font(.title3.bold())
                    .foregroundStyle(.black)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("Tambahkan air ke dalam wadah untuk menyesuaikan volume dasar larutan.")
                .font(.subheadline)
                .foregroundStyle(.black.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            let rowLayout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                : AnyLayout(HStackLayout(spacing: 12))

            rowLayout {
                Text("Jumlah Air")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.black)

                if !dynamicTypeSize.isAccessibilitySize {
                    Spacer(minLength: 8)
                }

                HStack(spacing: 12) {
                    Text("\(guide.jumlahAir) Liter")
                        .font(.subheadline.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(.black)

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
            .frame(minHeight: 54)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(pillBackground, in: .capsule)
        }
    }

    var tahap2PHView: some View {
        let additions = guide.sodaAdditions(currentPH: viewModel.latestWaterPH)

        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("TAHAP 2 DARI 3")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Tahap 2: Penyesuaian pH Air Larutan")
                    .font(.title3.bold())
                    .foregroundStyle(.black)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(additions, id: \.kode) { item in
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Tambahkan \(item.kode)")
                                .font(.subheadline.bold())
                                .foregroundStyle(.black)
                                .fixedSize(horizontal: false, vertical: true)

                            Text("Larutkan dengan air panas secukupnya.")
                                .font(.caption)
                                .foregroundStyle(.black.opacity(0.8))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer()

                        Text(formatGram(item.gram))
                            .font(.subheadline.bold())
                            .monospacedDigit()
                            .foregroundStyle(.black)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(pillBackground, in: .rect(cornerRadius: 20, style: .continuous))

            HStack {
                Text("Target level pH")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.black)

                Spacer()

                Text("12")
                    .font(.subheadline.bold())
                    .monospacedDigit()
                    .foregroundStyle(.black)
            }
            .padding(.horizontal, 20)
            .frame(height: 50)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(pillBackground, in: .capsule)

            HStack {
                Text("Level pH sekarang")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.black)

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: isPHReached ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.subheadline)
                    Text(formattedCurrentPH)
                        .font(.subheadline.bold())
                        .monospacedDigit()
                }
                .foregroundStyle(isPHReached ? successGreen : alertRed)
            }
            .padding(.horizontal, 20)
            .frame(height: 50)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isPHReached ? Color(red: 0.93, green: 0.98, blue: 0.93) : Color.white,
                in: .capsule
            )
            .overlay {
                Capsule()
                    .stroke(
                        isPHReached ? Color.clear : alertRed.opacity(0.65),
                        lineWidth: 1.2
                    )
            }

            Text("Tunggu beberapa saat agar larutan air mencapai target level pH semula.")
                .font(.caption)
                .foregroundStyle(.black.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
    }

    var tahap3KepekatanView: some View {
        let additions = guide.pewarnaAdditions(currentConcentration: viewModel.latestConcentration)
        let isReached = isConcentrationReached

        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("TAHAP 3 DARI 3")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Tahap 3: Penyesuaian Kepekatan Warna Larutan")
                    .font(.title3.bold())
                    .foregroundStyle(.black)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(additions, id: \.kode) { item in
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Tambahkan \(item.kode)")
                                .font(.subheadline.bold())
                                .foregroundStyle(.black)
                                .fixedSize(horizontal: false, vertical: true)

                            Text("Larutkan dengan air panas secukupnya.")
                                .font(.caption)
                                .foregroundStyle(.black.opacity(0.8))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer()

                        Text(formatGram(item.gram))
                            .font(.subheadline.bold())
                            .monospacedDigit()
                            .foregroundStyle(.black)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(pillBackground, in: .rect(cornerRadius: 20, style: .continuous))

            HStack {
                Text("Target kepekatan warna")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.black)

                Spacer()

                Text("100%")
                    .font(.subheadline.bold())
                    .monospacedDigit()
                    .foregroundStyle(.black)
            }
            .padding(.horizontal, 20)
            .frame(height: 50)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(pillBackground, in: .capsule)

            HStack {
                Text("Kepekatan warna sekarang")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.black)

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: isReached ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.subheadline)
                    Text(formattedCurrentConcentration)
                        .font(.subheadline.bold())
                        .monospacedDigit()
                }
                .foregroundStyle(isReached ? successGreen : alertRed)
            }
            .padding(.horizontal, 20)
            .frame(height: 50)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isReached ? Color(red: 0.93, green: 0.98, blue: 0.93) : Color.white,
                in: .capsule
            )
            .overlay {
                Capsule()
                    .stroke(
                        isReached ? Color.clear : alertRed.opacity(0.65),
                        lineWidth: 1.2
                    )
            }

            Text("Tunggu beberapa saat agar larutan air mencapai target kepekatan warna semula.")
                .font(.caption)
                .foregroundStyle(.black.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
    }
}
