//
//  PerbaikiLarutanView.swift
//  Serona
//

import SwiftUI

/// "Perbaiki Larutan": the steps that bring the water, pH and color concentration back above their limits.
struct PerbaikiLarutanView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var guide: PerbaikiLarutanViewModel
    @ObservedObject var viewModel: ProyekDetailViewModel

    init(issue: QualityIssue, viewModel: ProyekDetailViewModel) {
        _guide = State(wrappedValue: PerbaikiLarutanViewModel(
            issue: issue,
            proyek: viewModel.proyek,
            pHSebelum: viewModel.latestWaterPH
        ))
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Perbaiki Larutan")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity)

                    Text(
                        "Ikuti panduan penambahan bahan di bawah ini "
                            + "untuk mengembalikan kualitas larutan sesuai threshold."
                    )
                    .font(.callout)

                    ForEach(Array(guide.steps.enumerated()), id: \.element) { index, step in
                        stepCard(step, number: index + 1)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .navigationTitle("Perbaiki")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
        .onChange(of: guide.isFinished) { _, isFinished in
            if isFinished {
                dismiss()
            }
        }
    }

    private func stepCard(_ step: PerbaikiStep, number: Int) -> some View {
        let isActive = guide.isActive(step)
        return VStack(alignment: .leading, spacing: 12) {
            Text("Step \(number): \(title(of: step))")
                .font(.headline)

            Text(description(of: step))
                .font(.callout)

            content(of: step)

            Button {
                guide.lanjut(waterPH: viewModel.latestWaterPH)
            } label: {
                Text(guide.buttonTitle(for: step))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!isActive)
        }
        .padding(12)
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(isActive ? Color.accentColor : Color.secondary, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func content(of step: PerbaikiStep) -> some View {
        switch step {
        case .air:
            airRow
        case .phAir:
            if let soda = guide.penambahanSoda {
                ForEach(soda.bahan, id: \.kode) { bahan in
                    BarisInfo(
                        judul: "Tambahkan \(bahan.kode)",
                        nilai: Bahan.formatBerat(gram: bahan.gram),
                        tebal: true
                    )
                }
            } else {
                BarisInfo(judul: "Tambahkan Soda Abu", nilai: "\(PerbaikiLarutanViewModel.gramSodaAbu)gr", tebal: true)
            }
            BarisInfo(judul: "pH Sekarang", nilai: reading("current-water-ph"))
            BarisInfo(judul: "pH Awal", nilai: reading("initial-water-ph"))
        case .kepekatan:
            if let tambahan = viewModel.penambahanPewarna(volumeLiter: guide.volumeBakLiter) {
                ForEach(tambahan, id: \.kode) { bahan in
                    BarisInfo(
                        judul: "Tambahkan \(bahan.kode)",
                        nilai: Bahan.formatBerat(gram: bahan.gram),
                        tebal: true
                    )
                }
            } else {
                BarisInfo(
                    judul: "Tambahkan \(viewModel.proyek.pewarna.first?.kode ?? "Pewarna")",
                    nilai: "\(PerbaikiLarutanViewModel.gramPewarna)gr",
                    tebal: true
                )
            }
            BarisInfo(judul: "Kepekatan Warna Sekarang", nilai: reading("current-color-concentration"))
            BarisInfo(judul: "Kepekatan Warna Awal", nilai: reading("initial-color-concentration"))
        }
    }

    private var airRow: some View {
        HStack {
            Text("Tambahkan Air")
                .fontWeight(.semibold)

            Spacer()

            Text("\(guide.jumlahAir)")
                .monospacedDigit()
                .frame(minWidth: 72)
                .padding(.vertical, 8)
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.secondary.opacity(0.4))
                }

            Stepper("Jumlah air", value: $guide.jumlahAir, in: 0 ... 99)
                .labelsHidden()
                .disabled(!guide.isActive(.air))
        }
    }

    private func reading(_ id: String) -> String {
        viewModel.measurements.displayedMeasurements.first { $0.id == id }?.value ?? "—"
    }

    private func title(of step: PerbaikiStep) -> String {
        switch step {
        case .air: "Penambahan Air"
        case .phAir: "Penyesuaian pH"
        case .kepekatan: "Penyesuaian Kepekatan Warna"
        }
    }

    private func description(of step: PerbaikiStep) -> String {
        switch step {
        case .air: "Tambahkan air ke dalam wadah untuk menyesuaikan volume dasar larutan."
        case .phAir: "Tambahkan soda abu untuk menaikkan tingkat pH agar kembali ke pH awal pembuatan."
        case .kepekatan: "Tambahkan pewarna untuk mengembalikan kepekatan warna ke kepekatan warna awal pembuatan."
        }
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            PerbaikiLarutanView(
                issue: .keduanya,
                viewModel: ProyekDetailViewModel(proyek: .previewSample, service: SimulatedDeviceConnectionService())
            )
        }
}
