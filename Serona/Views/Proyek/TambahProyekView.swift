//
//  TambahProyekView.swift
//  Serona
//

import SwiftData
import SwiftUI

/// "Tambahkan Proyek": name, device, color and amount of fabric of a new project.
struct TambahProyekView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: TambahProyekViewModel
    @State private var isShowingDeviceList = false
    @State private var isShowingPilihResep = false
    @FocusState private var isNamaFocused: Bool

    init(viewModel: TambahProyekViewModel = TambahProyekViewModel()) {
        _viewModel = State(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    namaField
                    perangkatSection
                    JumlahKainBaris(jumlahKain: $viewModel.jumlahKain)
                    warnaSection
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Tambahkan Proyek")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        if viewModel.simpan(in: modelContext) != nil {
                            dismiss()
                        }
                    } label: {
                        Label("Simpan Proyek", systemImage: "arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.canSubmit)
                }
            }
        }
        .sheet(isPresented: $isShowingDeviceList) {
            DeviceListSheetView(
                onConnected: { viewModel.pilihPerangkat($0) },
                onDisconnected: { _ in Task { await viewModel.hapusPerangkat() } }
            )
        }
        .sheet(isPresented: $isShowingPilihResep) {
            PilihResepSheetView { viewModel.pilihResep($0) }
        }
        .alert(
            "Gagal menyimpan proyek",
            isPresented: saveErrorIsPresented,
            presenting: viewModel.saveError
        ) { _ in
            Button("Tutup", role: .cancel) {}
        } message: { error in
            Text(error)
        }
    }

    private var namaField: some View {
        VStack(alignment: .leading, spacing: 8) {
            JudulBagian(teks: "Nama Proyek")
            TextField("Cth: Seragam RT 5", text: $viewModel.nama)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)
                .focused($isNamaFocused)
                .submitLabel(.done)
        }
    }

    private var perangkatSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            JudulBagian(teks: "Perangkat")

            if let perangkat = viewModel.perangkat {
                HStack {
                    Label(perangkat.nama, systemImage: "wifi")
                        .font(.headline)
                        .foregroundStyle(.blue)

                    Spacer()

                    Button {
                        Task { await viewModel.hapusPerangkat() }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Putuskan \(perangkat.nama)")
                }
            }

            Button {
                isShowingDeviceList = true
            } label: {
                Text(viewModel.perangkat == nil ? "Pilih Perangkat" : "Ganti Perangkat")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private var warnaSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            JudulBagian(teks: "Warna")

            if let resep = viewModel.resep {
                WarnaSwatchView(namaWarna: resep.namaWarna, warnaHex: resep.warnaHex) {
                    viewModel.hapusResep()
                }
                ResepWarnaView(
                    pewarna: resep.pewarna,
                    zatPembantu: resep.zatPembantu,
                    air: resep.air > 0 ? resep.air : nil
                )
            } else {
                Button {
                    isShowingPilihResep = true
                } label: {
                    Text("Pilih Warna")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }

    private var saveErrorIsPresented: Binding<Bool> {
        Binding(
            get: { viewModel.saveError != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.clearSaveError()
                }
            }
        )
    }
}

#Preview {
    let viewModel = TambahProyekViewModel(service: SimulatedDeviceConnectionService())
    viewModel.pilihPerangkat(SimulatedDeviceConnectionService.devices[0])
    return Color.clear
        .sheet(isPresented: .constant(true)) {
            TambahProyekView(viewModel: viewModel)
        }
        .modelContainer(for: SeronaSchema.models, inMemory: true)
}
