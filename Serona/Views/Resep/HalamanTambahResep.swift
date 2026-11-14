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
    @State private var pesanGagalSimpan = ""
    @State private var gagalMenghapus = false
    @State private var konfirmasiHapus = false

    private let tampilSebagaiSheet: Bool
    private let titleColor = Color("titleColor")
    private let oliveGreen = Color("oliveGreen")

    init(resep: Resep? = nil, tampilSebagaiSheet: Bool = false) {
        self.tampilSebagaiSheet = tampilSebagaiSheet
        _viewModel = State(
            initialValue: resep.map { FormResepViewModel(resep: $0) } ?? FormResepViewModel()
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    namaWarnaCard
                    resepWarnaCard
                    batasCard
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.white)
            .navigationTitle(viewModel.sedangMengedit ? viewModel.namaWarna : "Tambah Warna")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        simpan()
                    } label: {
                        Label("Simpan", systemImage: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(oliveGreen)
                    .disabled(!viewModel.bisaSimpan)
                }
            }
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
    }

    // MARK: - Section Cards

    private var namaWarnaCard: some View {
        cardSection {
            VStack(alignment: .leading, spacing: 8) {
                Text("Nama Warna")
                    .font(.headline)
                    .foregroundStyle(titleColor)

                TextField("Cth: Merah Marun", text: $viewModel.namaWarna)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
            }
        }
    }

    private var resepWarnaCard: some View {
        cardSection {
            VStack(alignment: .leading, spacing: 16) {
                Text("Resep Warna")
                    .font(.headline)
                    .foregroundStyle(titleColor)

                // Pewarna Subsection
                VStack(alignment: .leading, spacing: 10) {
                    Label("Kode Pewarna Naphtol", systemImage: "cylinder.split.1x2")
                        .font(.subheadline.bold())
                        .foregroundStyle(titleColor)

                    ForEach($viewModel.pewarna) { $item in
                        BahanRowView(
                            item: $item,
                            pilihan: viewModel.daftarPilihanPewarna,
                            titleColor: titleColor,
                            onHapus: {
                                viewModel.pewarna.removeAll { $0.id == item.id }
                            }
                        )
                    }

                    OliveCapsuleButton(title: "Tambah Pewarna", systemImage: "plus") {
                        withAnimation {
                            viewModel.pewarna.append(BahanInput())
                        }
                    }
                    .disabled(!barisLengkap(viewModel.pewarna))
                }

                Divider()

                // Air Subsection
                HStack {
                    Label("Air", systemImage: "drop.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(titleColor)

                    Spacer()

                    HStack(spacing: 12) {
                        TextField("0", value: $viewModel.ukuranAir, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 88)

                        Text("L")
                            .font(.subheadline)
                            .foregroundStyle(titleColor)
                    }
                }

                Divider()

                // Zat Pembantu Subsection
                VStack(alignment: .leading, spacing: 10) {
                    Label("Zat Pembantu", systemImage: "cylinder.split.1x2")
                        .font(.subheadline.bold())
                        .foregroundStyle(titleColor)

                    ForEach($viewModel.zatPembantu) { $item in
                        BahanRowView(
                            item: $item,
                            pilihan: viewModel.daftarPilihanZatPembantu,
                            titleColor: titleColor,
                            onHapus: {
                                viewModel.zatPembantu.removeAll { $0.id == item.id }
                            }
                        )
                    }

                    OliveCapsuleButton(title: "Tambah Zat Pembantu", systemImage: "plus") {
                        withAnimation {
                            viewModel.zatPembantu.append(BahanInput())
                        }
                    }
                    .disabled(!barisLengkap(viewModel.zatPembantu))
                }
            }
        }
    }

    private var batasCard: some View {
        cardSection {
            VStack(alignment: .leading, spacing: 15) {
                Text("Batas")
                    .font(.headline)
                    .foregroundStyle(titleColor)

                BarisBatas(
                    label: "Kepekatan Warna (%)",
                    nilai: $viewModel.kepekatan,
                    rentang: 0 ... 100
                )

                BarisBatas(
                    label: "Batas pH",
                    nilai: $viewModel.batasPH,
                    rentang: 0 ... 14
                )

                Text("""
                Nilai ini adalah batas minimum rekomendasi dan dapat Anda ubah kapan saja. \
                Notifikasi akan dikirim jika nilai turun di bawah batas ini
                """)
                .font(.caption)
                .italic()
                .foregroundStyle(.secondary)

                if viewModel.sedangMengedit {
                    Button(role: .destructive) {
                        konfirmasiHapus = true
                    } label: {
                        Label("Hapus Warna", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .padding(.top, 8)
                }
            }
        }
    }

    private func cardSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading) {
            content()
        }
        .padding()
        .background(Color.white, in: .rect(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 3)
    }

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
    @Environment(\.isEnabled) private var isEnabled
    let title: String
    var systemImage: String? = nil
    let action: () -> Void

    private let oliveGreen = Color("oliveGreen")

    var body: some View {
        Button(action: action) {
            Group {
                if let systemImage {
                    Label(title, systemImage: systemImage)
                } else {
                    Text(title)
                }
            }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .tint(isEnabled ? oliveGreen : Color.gray.opacity(0.4))
    }
}

private struct BahanRowView: View {
    @Binding var item: BahanInput
    let pilihan: [String]
    let titleColor: Color
    let onHapus: () -> Void

    var body: some View {
        HStack {
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
                        .foregroundStyle(item.kode.isEmpty ? Color.gray : titleColor)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: 260)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            }

            Spacer()

            HStack(spacing: 10) {
                TextField("0", value: $item.gram, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 88)

                Text("gr")
                    .font(.subheadline)
                    .foregroundStyle(titleColor)
            }
        }
    }
}

// MARK: - Previews

#Preview("Tambah Warna Sheet (iPadOS)", traits: .landscapeLeft) {
    HalamanTambahResep(tampilSebagaiSheet: true)
        .modelContainer(for: SeronaSchema.models, inMemory: true)
}
