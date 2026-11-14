//
//  TambahProyekView.swift
//  Serona
//

import SwiftData
import SwiftUI

struct TambahProyekView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: TambahProyekViewModel
    @State private var isShowingDeviceList = false
    @State private var isShowingPilihResep = false
    @FocusState private var isNamaFocused: Bool

    var onProyekCreated: ((Proyek) -> Void)?

    private let titleColor = Color("titleColor")
    private let oliveGreen = Color("oliveGreen")
    private let backgroundColor = Color("backgroundColor")
    private let tileBackground = Color(red: 0.95, green: 0.96, blue: 0.93)

    init(
        viewModel: TambahProyekViewModel = TambahProyekViewModel(),
        onProyekCreated: ((Proyek) -> Void)? = nil
    ) {
        _viewModel = State(wrappedValue: viewModel)
        self.onProyekCreated = onProyekCreated
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    namaAndAirCard
                    perangkatCard
                    warnaCard

                    if let resep = viewModel.resep {
                        resepWarnaCard(resep: resep)
                    }
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.white)
            .navigationTitle("Tambah Proyek")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        if let newProyek = viewModel.simpan(in: modelContext) {
                            onProyekCreated?(newProyek)
                            dismiss()
                        }
                    } label: {
                        Label("Simpan Proyek", systemImage: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(oliveGreen)
                    .disabled(!viewModel.canSubmit)
                }
            }
            .task { isNamaFocused = true }
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
    }

    // MARK: - Section Cards

    private var namaAndAirCard: some View {
        cardSection {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Nama Bak")
                        .font(.headline)
                        .foregroundStyle(titleColor)

                    TextField("Proyek SDK Cendrawasih", text: $viewModel.nama)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .focused($isNamaFocused)
                }

                HStack {
                    Text("Air")
                        .font(.headline)
                        .foregroundStyle(titleColor)

                    Spacer()

                    HStack(spacing: 8) {
                        Text("\(viewModel.jumlahKain)")
                            .font(.subheadline.weight(.medium))
                            .frame(width: 44, height: 36)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )

                        Text("L")
                            .font(.subheadline)
                            .foregroundStyle(titleColor)

                        HStack(spacing: 0) {
                            Button {
                                if viewModel.jumlahKain > 0 { viewModel.jumlahKain -= 1 }
                            } label: {
                                Image(systemName: "minus")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(titleColor)
                                    .frame(width: 36, height: 36)
                            }

                            Divider()
                                .frame(height: 20)

                            Button {
                                viewModel.jumlahKain += 1
                            } label: {
                                Image(systemName: "plus")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(titleColor)
                                    .frame(width: 36, height: 36)
                            }
                        }
                        .background(tileBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
    }

    private var perangkatCard: some View {
        cardSection {
            HStack {
                Text("Perangkat")
                    .font(.headline)
                    .foregroundStyle(titleColor)

                Spacer()

                if let perangkat = viewModel.perangkat {
                    HStack(spacing: 8) {
                        Image(systemName: "wifi")
                            .foregroundStyle(.gray)

                        Text(perangkat.nama)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.gray)

                        Button {
                            Task { await viewModel.hapusPerangkat() }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.red)
                        }
                    }
                } else {
                    Button {
                        isShowingDeviceList = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text("Hubungkan")
                        }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(oliveGreen)
                        .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private var warnaCard: some View {
        cardSection {
            VStack(alignment: .leading, spacing: 10) {
                Text("Warna")
                    .font(.headline)
                    .foregroundStyle(titleColor)

                if let resep = viewModel.resep {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(resep.namaWarna)
                            .font(.subheadline.weight(.semibold))
                            .italic()
                            .foregroundStyle(Color.gray)

                        ZStack(alignment: .trailing) {
                            WarnaKotak(hex: resep.warnaHex, cornerRadius: 12, iconSize: 22)
                                .frame(height: 50)

                            Button {
                                viewModel.hapusResep()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.white)
                            }
                            .padding(.trailing, 12)
                        }
                    }
                } else {
                    Button {
                        isShowingPilihResep = true
                    } label: {
                        Text("Pilih Warna")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(height: 44)
                            .frame(maxWidth: .infinity)
                            .background(oliveGreen)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private func resepWarnaCard(resep: Resep) -> some View {
        cardSection {
            VStack(alignment: .leading, spacing: 14) {
                Text("Resep Warna")
                    .font(.headline)
                    .foregroundStyle(titleColor)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "cylinder.split.1x2")
                            .foregroundStyle(titleColor)
                        Text("Kode Pewarna Naphtol")
                            .font(.subheadline.bold())
                            .foregroundStyle(titleColor)
                    }

                    ForEach(resep.pewarna, id: \.kode) { bahan in
                        readOnlyIngredientRow(name: bahan.kode, amount: "\(Int(bahan.gram))", unit: "gr")
                    }
                }

                Divider()

                HStack {
                    Image(systemName: "drop.fill")
                        .foregroundStyle(titleColor)

                    Text("Air")
                        .font(.subheadline.bold())
                        .foregroundStyle(titleColor)

                    Spacer()

                    Text("\(resep.air)")
                        .font(.subheadline)
                        .frame(width: 50, height: 32)
                        .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3), lineWidth: 1))

                    Text("L")
                        .font(.subheadline)
                        .foregroundStyle(titleColor)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "cylinder.split.1x2")
                            .foregroundStyle(titleColor)
                        Text("Zat Pembantu")
                            .font(.subheadline.bold())
                            .foregroundStyle(titleColor)
                    }

                    ForEach(resep.zatPembantu, id: \.kode) { bahan in
                        readOnlyIngredientRow(name: bahan.kode, amount: "\(Int(bahan.gram))", unit: "gr")
                    }
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

    private func readOnlyIngredientRow(name: String, amount: String, unit: String) -> some View {
        HStack {
            Text(name)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1))

            Spacer()

            HStack(spacing: 6) {
                Text(amount)
                    .font(.subheadline)
                    .frame(width: 50, height: 32)
                    .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3), lineWidth: 1))

                Text(unit)
                    .font(.subheadline)
                    .foregroundStyle(titleColor)
            }
        }
    }

    private var saveErrorIsPresented: Binding<Bool> {
        Binding(
            get: { viewModel.saveError != nil },
            set: { isPresented in
                if !isPresented { viewModel.clearSaveError() }
            }
        )
    }
}

// MARK: - Previews

#Preview("Tambah Proyek Sheet", traits: .landscapeLeft) {
    TambahProyekView()
        .modelContainer(for: SeronaSchema.models, inMemory: true)
}
