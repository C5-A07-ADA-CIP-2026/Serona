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

    var tahap2PHView: some View {
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

    var tahap3KepekatanView: some View {
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
}
