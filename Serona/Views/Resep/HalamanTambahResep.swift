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
    private let backgroundColor = Color("backgroundColor")

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
                    warnaSelectionCard
                    resepWarnaCard
                    batasCard
                }
                .padding(20)
            }
            .background(backgroundColor.ignoresSafeArea())
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
                    if viewModel.kepekatan == nil { viewModel.kepekatan = 80 }
                    if viewModel.batasPH == nil { viewModel.batasPH = 7 }
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
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(titleColor)

                TextField("Proyek SDK Cendrawasih", text: $viewModel.namaWarna)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            }
        }
    }

    private var warnaSelectionCard: some View {
        cardSection {
            VStack(alignment: .leading, spacing: 10) {
                Text("Warna")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(titleColor)

                if let warna = viewModel.warnaDipilih {
                    VStack(alignment: .leading, spacing: 6) {
                        if !viewModel.namaWarna.isEmpty {
                            Text(viewModel.namaWarna)
                                .font(.system(size: 14, weight: .semibold))
                                .italic()
                                .foregroundStyle(Color.gray)
                        }

                        ZStack(alignment: .trailing) {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(warna)
                                .frame(height: 50)

                            Button {
                                withAnimation {
                                    viewModel.warnaDipilih = nil
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(.white)
                            }
                            .padding(.trailing, 12)
                        }
                    }
                } else {
                    HStack(spacing: 12) {
                        OliveCapsuleButton(title: "Scan Warna") {
                            withAnimation {
                                viewModel.warnaDipilih = Color(hex: "#C0533E")
                            }
                        }

                        PilihWarnaButton(selectedColor: $viewModel.warnaDipilih)
                    }
                }
            }
        }
    }

    private var resepWarnaCard: some View {
        cardSection {
            VStack(alignment: .leading, spacing: 16) {
                Text("Resep Warna")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(titleColor)

                // Pewarna Subsection
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "cylinder.split.1x2")
                            .foregroundStyle(titleColor)
                        Text("Kode Pewarna Naphtol")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(titleColor)
                    }

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
                }

                Divider()

                // Air Subsection
                HStack {
                    Image(systemName: "drop.fill")
                        .foregroundStyle(titleColor)

                    Text("Air")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(titleColor)

                    Spacer()

                    HStack(spacing: 6) {
                        TextField("0", value: $viewModel.ukuranAir, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .frame(width: 60)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )

                        Text("L")
                            .font(.system(size: 14))
                            .foregroundStyle(titleColor)
                    }
                }

                Divider()

                // Zat Pembantu Subsection
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "cylinder.split.1x2")
                            .foregroundStyle(titleColor)
                        Text("Zat Pembantu")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(titleColor)
                    }

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
                }
            }
        }
    }

    private var batasCard: some View {
        cardSection {
            VStack(alignment: .leading, spacing: 15) {
                Text("Batas")
                    .font(.system(size: 16, weight: .bold))
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
                            .frame(height: 44)
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
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
}

// MARK: - Helper Subviews

private struct OliveCapsuleButton: View {
    let title: String
    var systemImage: String? = nil
    let action: () -> Void

    private let oliveGreen = Color("oliveGreen")

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(height: 44)
            .frame(maxWidth: .infinity)
            .background(oliveGreen)
            .clipShape(Capsule())
        }
    }
}

private struct PilihWarnaButton: View {
    @Binding var selectedColor: Color?
    @State private var pickerColor: Color = .blue
    private let oliveGreen = Color("oliveGreen")

    var body: some View {
        ZStack {
            Text("Pilih Warna")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(oliveGreen)
                .frame(height: 44)
                .frame(maxWidth: .infinity)
                .background(
                    Capsule().stroke(oliveGreen, lineWidth: 1.5)
                )

            ColorPicker("", selection: $pickerColor, supportsOpacity: false)
                .labelsHidden()
                .scaleEffect(x: 15, y: 2)
                .opacity(0.02)
        }
        .frame(height: 44)
        .frame(maxWidth: .infinity)
        .contentShape(Capsule())
        .onChange(of: pickerColor) { _, newColor in
            withAnimation {
                selectedColor = newColor
            }
        }
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
                        .font(.system(size: 14))
                        .foregroundStyle(item.kode.isEmpty ? Color.gray : titleColor)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12))
                        .foregroundStyle(.gray)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(width: 150)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            }

            Spacer()

            HStack(spacing: 6) {
                TextField("0", value: $item.gram, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .frame(width: 55)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )

                Text("gr")
                    .font(.system(size: 14))
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
