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
    
    init(resep: Resep? = nil) {
        _viewModel = State(
            initialValue: resep.map { FormResepViewModel(resep: $0) } ?? FormResepViewModel()
        )
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    KolomTeks(
                        judul: "Nama Warna",
                        placeholder: "Cth: Merah Marun",
                        teks: $viewModel.namaWarna
                    )
                    PemilihWarna(warna: $viewModel.warnaDipilih)
                    bagianBahan
                    bagianBatas
                }
                .padding(24)
            }
            .navigationTitle(viewModel.sedangMengedit ? viewModel.namaWarna : "Tambah Warna")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarForm }
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
    
    private var bagianBahan: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Bahan")
                .font(.judulBold)
            
            DaftarBahan(
                judul: "Kode Pewarna Naphtol",
                labelTambah: "Tambah Pewarna",
                bahan: $viewModel.pewarna,
                pilihanTersedia: viewModel.daftarPilihanPewarna
            )
            
            BarisIsian(label: "Air", satuan: "L", labelTebal: true) {
                TextField("0", value: $viewModel.ukuranAir, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .frame(width: UkuranKolom.lebarAngka)
            }
            
            DaftarBahan(
                judul: "Zat Pembantu",
                labelTambah: "Tambah Zat Pembantu",
                bahan: $viewModel.zatPembantu,
                pilihanTersedia: viewModel.daftarPilihanZatPembantu
            )
        }
    }
    
    private var bagianBatas: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Batas")
                .font(.judulBold)
            
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
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            
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
    
    @ToolbarContentBuilder
    private var toolbarForm: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(role: .close) { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button {
                simpan()
            } label: {
                Label("Simpan", systemImage: "checkmark")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.bisaSimpan)
        }
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            HalamanTambahResep()
        }
}
