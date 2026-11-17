//
//  HalamanTambahResep.swift
//  Serona
//
//  Created by Dina on 21/10/26.
//

import SwiftData
import SwiftUI

struct HalamanTambahResep: View {
    @State private var viewModel: FormResepViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var gagalMenyimpan = false
    @State private var gagalMenghapus = false
    @State private var konfirmasiHapus = false

    private let tampilSebagaiSheet: Bool
    private let titleColor = Color("titleColor")
    private let oliveGreen = Color("oliveGreen")

    init(resep: Resep? = nil, tampilSebagaiSheet: Bool = false) {
        self.tampilSebagaiSheet = tampilSebagaiSheet
        if let resep {
            _viewModel = State(initialValue: FormResepViewModel(resep: resep))
        } else {
            let formViewModel = FormResepViewModel()
            formViewModel.pewarna = []
            formViewModel.zatPembantu = []
            formViewModel.kepekatan = 90
            formViewModel.batasPH = 11
            _viewModel = State(initialValue: formViewModel)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    namaWarnaCard
                    pewarnaSection
                    airSection
                    zatPembantuSection

                    if viewModel.sedangMengedit {
                        hapusButton
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 4)
                .padding(.bottom, 28)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Color.white)
        .presentationSizing(.form)
        .presentationBackground(Color.white)
        .presentationDragIndicator(.visible)
        .onAppear {
            if !viewModel.sedangMengedit {
                if viewModel.kepekatan == nil {
                    viewModel.kepekatan = 90
                }
                if viewModel.batasPH == nil {
                    viewModel.batasPH = 11
                }
            }
        }
        .alert("Gagal menyimpan", isPresented: $gagalMenyimpan) {
            Button("Tutup", role: .cancel) {}
        }
        .alert("Gagal menghapus", isPresented: $gagalMenghapus) {
            Button("Tutup", role: .cancel) {}
        }
        .alert("Hapus Warna?", isPresented: $konfirmasiHapus) {
            Button("Batal", role: .cancel) {}
            Button("Hapus", role: .destructive) { hapus() }
        } message: {
            Text("Warna ini akan dihapus dari daftar. Proyek yang sudah dibuat dengan warna ini tidak terpengaruh.")
        }
    }

    // MARK: - Top Header Bar

    private var headerBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .frame(width: 40, height: 40)
                    .background(Color(UIColor.systemGray5))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Tutup")

            Spacer()

            Text(viewModel.sedangMengedit ? viewModel.namaWarna : "Tambah Warna")
                .font(.headline.bold())
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()

            Button {
                simpan()
            } label: {
                Image(systemName: "checkmark")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(viewModel.bisaSimpan ? oliveGreen : Color.gray.opacity(0.65))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.bisaSimpan)
            .accessibilityLabel("Simpan Warna")
        }
    }

    // MARK: - Sections

    private var namaWarnaCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Nama Warna")
                .font(.headline)
                .foregroundStyle(.black)

            TextField("", text: $viewModel.namaWarna)
                .font(.subheadline)
                .autocorrectionDisabled()
                .padding(.horizontal, 12)
                .frame(height: 40)
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                )
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private var pewarnaSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "cylinder.split.1x2")
                    .font(.title3)
                    .foregroundStyle(.primary)
                    .frame(width: 24)

                Text("Kode Pewarna Naphtol")
                    .font(.headline)
                    .foregroundStyle(.primary)
            }

            ForEach($viewModel.pewarna) { $item in
                BahanRowView(
                    item: $item,
                    pilihan: viewModel.daftarPilihanPewarna,
                    titleColor: titleColor
                )
            }

            OliveCapsuleButton(
                title: "Tambah Pewarna",
                systemImage: "plus",
                isEnabled: barisLengkap(viewModel.pewarna)
            ) {
                withAnimation(.snappy) {
                    viewModel.pewarna.append(BahanInput())
                }
            }
        }
    }

    private var airSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "drop.fill")
                .font(.title3)
                .foregroundStyle(.primary)
                .frame(width: 24)

            Text("Air")
                .font(.headline)
                .foregroundStyle(.primary)

            Spacer()

            HStack(spacing: 10) {
                TextField("0", value: $viewModel.ukuranAir, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(titleColor)
                    .monospacedDigit()
                    .frame(width: 64, height: 38)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                    )

                Text("L")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(titleColor)
                    .frame(width: 20, alignment: .leading)
            }
        }
    }

    private var zatPembantuSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "cylinder.split.1x2")
                    .font(.title3)
                    .foregroundStyle(.primary)
                    .frame(width: 24)

                Text("Zat Pembantu")
                    .font(.headline)
                    .foregroundStyle(.primary)
            }

            ForEach($viewModel.zatPembantu) { $item in
                BahanRowView(
                    item: $item,
                    pilihan: viewModel.daftarPilihanZatPembantu,
                    titleColor: titleColor
                )
            }

            OliveCapsuleButton(
                title: "Tambah Zat Pembantu",
                systemImage: "plus",
                isEnabled: barisLengkap(viewModel.zatPembantu)
            ) {
                withAnimation(.snappy) {
                    viewModel.zatPembantu.append(BahanInput())
                }
            }
        }
    }

    private var hapusButton: some View {
        Button(role: .destructive) {
            konfirmasiHapus = true
        } label: {
            Label("Hapus Warna", systemImage: "trash")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .padding(.top, 4)
    }

    // MARK: - Actions

    private func simpan() {
        do {
            try viewModel.simpan(context: modelContext)
            dismiss()
        } catch {
            gagalMenyimpan = true
        }
    }

    private func hapus() {
        do {
            try viewModel.hapus(context: modelContext)
            dismiss()
        } catch {
            gagalMenghapus = true
        }
    }

    private func barisLengkap(_ daftar: [BahanInput]) -> Bool {
        daftar.allSatisfy { !$0.kode.isEmpty && ($0.gram ?? 0) > 0 }
    }
}

// MARK: - Helper Subviews

private struct OliveCapsuleButton: View {
    let title: String
    var systemImage: String?
    var isEnabled: Bool = true
    let action: () -> Void

    private let oliveGreen = Color("oliveGreen")

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.subheadline.bold())
                }
                Text(title)
                    .font(.subheadline.bold())
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(isEnabled ? oliveGreen : Color.gray.opacity(0.45), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

private struct BahanRowView: View {
    @Binding var item: BahanInput
    let pilihan: [String]
    let titleColor: Color

    var body: some View {
        HStack(spacing: 12) {
            Menu {
                ForEach(pilihan, id: \.self) { opsi in
                    Button(opsi) {
                        item.kode = opsi
                    }
                }
            } label: {
                HStack {
                    Text(item.kode.isEmpty ? "Pilih Kode" : item.kode)
                        .font(.subheadline)
                        .foregroundStyle(item.kode.isEmpty ? Color.gray : .primary)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.black)
                }
                .padding(.horizontal, 12)
                .frame(width: 195, height: 38)
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                )
            }

            Spacer()

            HStack(spacing: 10) {
                TextField("0", value: $item.gram, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .font(.subheadline.weight(.medium))
                    .monospacedDigit()
                    .frame(width: 64, height: 38)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                    )

                Text("gr")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(titleColor)
                    .frame(width: 20, alignment: .leading)
            }
        }
        .padding(.leading, 34)
    }
}

// MARK: - Previews

#Preview("Tambah Warna Sheet (iPadOS)", traits: .landscapeLeft) {
    BackgroundGradient()
        .sheet(isPresented: .constant(true)) {
            HalamanTambahResep(tampilSebagaiSheet: true)
        }
        .modelContainer(for: SeronaSchema.models, inMemory: true)
}
