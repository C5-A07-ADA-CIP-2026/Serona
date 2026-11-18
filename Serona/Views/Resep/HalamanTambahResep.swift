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
    private let oliveGreen = Color("oliveGreen")
    private let latarBelakang = Color("backgroundModal")

    init(resep: Resep? = nil, tampilSebagaiSheet: Bool = false) {
        self.tampilSebagaiSheet = tampilSebagaiSheet
        if let resep {
            _viewModel = State(initialValue: FormResepViewModel(resep: resep))
        } else {
            let formViewModel = FormResepViewModel()
            formViewModel.pewarna = [BahanInput()]
            formViewModel.zatPembantu = [BahanInput()]
            formViewModel.kepekatan = 90
            formViewModel.batasPH = 11
            _viewModel = State(initialValue: formViewModel)
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            latarBelakang.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    namaWarnaCard
                    jumlahAirCard
                    pewarnaSection
                    zatPembantuSection

                    if viewModel.sedangMengedit {
                        hapusButton
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 76)
                .padding(.bottom, 28)
            }
            .scrollDismissesKeyboard(.interactively)

            headerBar
                .padding(.horizontal, 20)
                .padding(.top, 16)
        }
        .presentationBackground(latarBelakang)
        .presentationDragIndicator(.hidden)
        .onAppear {
            if !viewModel.sedangMengedit {
                if viewModel.kepekatan == nil { viewModel.kepekatan = 90 }
                if viewModel.batasPH == nil { viewModel.batasPH = 11 }
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

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.primary)
                    .frame(width: 48, height: 48)
                    .background(Color.white, in: Circle())
                    .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Tutup")

            Spacer()

            Text("Warna")
                .font(.headline)
                .foregroundStyle(.primary)

            Spacer()

            Button {
                simpan()
            } label: {
                Image(systemName: "checkmark")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(viewModel.bisaSimpan ? oliveGreen : Color.gray.opacity(0.65), in: Circle())
                    .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 3)
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.bisaSimpan)
            .accessibilityLabel("Simpan Warna")
        }
    }

    // MARK: - Nama Warna & Jumlah Air

    private var namaWarnaCard: some View {
        HStack {
            Text("Nama Warna")
                .font(.title3)
                .foregroundStyle(.primary)

            TextField("Contoh: Marun", text: $viewModel.namaWarna)
                .font(.title3)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.secondary)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 26)
        .frame(height: 60)
        .background(Color.white, in: Capsule())
    }

    private var jumlahAirCard: some View {
        HStack {
            Text("Jumlah Air")
                .font(.title3)
                .foregroundStyle(.primary)

            Spacer()

            Text("\(viewModel.ukuranAir ?? 0) Liter")
                .font(.title3)
                .foregroundStyle(.primary)
                .monospacedDigit()

            HStack(spacing: 0) {
                Button {
                    let sekarang = viewModel.ukuranAir ?? 0
                    if sekarang > 0 {
                        viewModel.ukuranAir = sekarang - 1
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.body.weight(.bold))
                        .foregroundStyle(.primary)
                        .frame(width: 58, height: 40)
                }

                Rectangle()
                    .fill(Color.gray.opacity(0.35))
                    .frame(width: 1, height: 26)

                Button {
                    viewModel.ukuranAir = (viewModel.ukuranAir ?? 0) + 1
                } label: {
                    Image(systemName: "plus")
                        .font(.body.weight(.bold))
                        .foregroundStyle(.primary)
                        .frame(width: 58, height: 40)
                }
            }
            .background(Color(UIColor.systemGray5), in: Capsule())
            .buttonStyle(.plain)
        }
        .padding(.leading, 26)
        .padding(.trailing, 18)
        .frame(height: 70)
        .background(Color.white, in: Capsule())
    }

    // MARK: - Napthol

    private var pewarnaSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(viewModel.pewarna.enumerated()), id: \.element.id) { index, item in
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(
                        title: "Napthol \(index + 1)",
                        tampilkanHapus: index > 0
                    ) {
                        withAnimation(.snappy) {
                            viewModel.pewarna.removeAll { $0.id == item.id }
                        }
                    }

                    BahanCard(
                        labelKode: "Kode Pewarna",
                        item: bindingPewarna(item.id),
                        pilihan: viewModel.pilihanPewarna(untuk: item)
                    )
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            TambahButton(
                title: "Tambah Napthol",
                isEnabled: viewModel.bisaTambahPewarna,
                warna: oliveGreen
            ) {
                withAnimation(.snappy) {
                    viewModel.pewarna.append(BahanInput())
                }
            }
        }
    }

    // MARK: - Zat Pembantu

    private var zatPembantuSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(viewModel.zatPembantu.enumerated()), id: \.element.id) { index, item in
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(
                        title: index == 0 ? "Zat Pembantu" : "Zat Pembantu \(index + 1)",
                        tampilkanHapus: index > 0
                    ) {
                        withAnimation(.snappy) {
                            viewModel.zatPembantu.removeAll { $0.id == item.id }
                        }
                    }

                    BahanCard(
                        labelKode: "Soda",
                        item: bindingZatPembantu(item.id),
                        pilihan: viewModel.pilihanZatPembantu(untuk: item)
                    )
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            TambahButton(
                title: "Tambah Zat Pembantu",
                isEnabled: viewModel.bisaTambahZatPembantu,
                warna: oliveGreen
            ) {
                withAnimation(.snappy) {
                    viewModel.zatPembantu.append(BahanInput())
                }
            }
        }
    }

    // MARK: - Hapus

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
    
    private func bindingPewarna(_ id: BahanInput.ID) -> Binding<BahanInput> {
        Binding(
            get: { viewModel.pewarna.first(where: { $0.id == id }) ?? BahanInput() },
            set: { baru in
                if let i = viewModel.pewarna.firstIndex(where: { $0.id == id }) {
                    viewModel.pewarna[i] = baru
                }
            }
        )
    }

    private func bindingZatPembantu(_ id: BahanInput.ID) -> Binding<BahanInput> {
        Binding(
            get: { viewModel.zatPembantu.first(where: { $0.id == id }) ?? BahanInput() },
            set: { baru in
                if let i = viewModel.zatPembantu.firstIndex(where: { $0.id == id }) {
                    viewModel.zatPembantu[i] = baru
                }
            }
        )
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
}

// MARK: - Helper Subviews

private struct SectionHeader: View {
    let title: String
    var tampilkanHapus: Bool = false
    var onHapus: () -> Void = {}

    var body: some View {
        HStack {
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(.primary)

            Spacer()

            if tampilkanHapus {
                Button(action: onHapus) {
                    Image(systemName: "trash")
                        .font(.title3)
                        .foregroundStyle(.red.opacity(0.85))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Hapus")
            }
        }
        .padding(.horizontal, 2)
        .padding(.top, 4)
    }
}

private struct BahanCard: View {
    let labelKode: String
    @Binding var item: BahanInput
    let pilihan: [String]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(labelKode)
                    .font(.title3)
                    .foregroundStyle(.primary)

                Spacer()

                Menu {
                    ForEach(pilihan, id: \.self) { opsi in
                        Button(opsi) { item.kode = opsi }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(item.kode.isEmpty ? "Pilih" : item.kode)
                            .font(.title3)
                            .foregroundStyle(.gray)
                            .lineLimit(1)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.gray)
                    }
                }
            }
            .frame(height: 48)

            Divider()
                .overlay(Color.gray.opacity(0.5))
                .padding(.horizontal, 8)

            HStack {
                Text("Berat")
                    .font(.title3)
                    .foregroundStyle(.primary)

                Spacer()

                TextField("0", value: $item.gram, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(width: 90)

                Text("gr")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .frame(height: 48)
            .padding(.trailing, 8)
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 8)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
    }
}

private struct TambahButton: View {
    let title: String
    var isEnabled: Bool = true
    let warna: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "plus.circle")
                    .font(.title2)
                Text(title)
                    .font(.title3)
                Spacer()
            }
            .foregroundStyle(isEnabled ? warna : Color.gray.opacity(0.6))
            .padding(.horizontal, 26)
            .frame(height: 60)
            .background(Color.white, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
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
