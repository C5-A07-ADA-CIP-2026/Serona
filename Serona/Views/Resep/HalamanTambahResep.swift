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
        JumlahAirCard(ukuranAir: $viewModel.ukuranAir)
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
        bindingBahan(\.pewarna, id: id)
    }

    private func bindingZatPembantu(_ id: BahanInput.ID) -> Binding<BahanInput> {
        bindingBahan(\.zatPembantu, id: id)
    }

    private func bindingBahan(
        _ daftar: ReferenceWritableKeyPath<FormResepViewModel, [BahanInput]>,
        id: BahanInput.ID
    ) -> Binding<BahanInput> {
        Binding(
            get: { viewModel[keyPath: daftar].first(where: { $0.id == id }) ?? BahanInput() },
            set: { baru in
                if let indeks = viewModel[keyPath: daftar].firstIndex(where: { $0.id == id }) {
                    viewModel[keyPath: daftar][indeks] = baru
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

// MARK: - Previews

#Preview("Tambah Warna Sheet (iPadOS)", traits: .landscapeLeft) {
    BackgroundGradient()
        .sheet(isPresented: .constant(true)) {
            HalamanTambahResep(tampilSebagaiSheet: true)
        }
        .modelContainer(for: SeronaSchema.models, inMemory: true)
}
