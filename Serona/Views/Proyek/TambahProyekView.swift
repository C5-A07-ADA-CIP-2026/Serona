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

    // Callback triggered when a new project is saved to immediately start scanning
    var onProyekCreated: ((Proyek) -> Void)?

    // Color Palette
    private let titleColor = Color(red: 0.38, green: 0.15, blue: 0.15)
    private let oliveGreen = Color(red: 0.35, green: 0.42, blue: 0.25)
    private let sheetBg = Color(red: 0.98, green: 0.97, blue: 0.93)
    private let tileBackground = Color(red: 0.95, green: 0.96, blue: 0.93)

    init(
        viewModel: TambahProyekViewModel = TambahProyekViewModel(),
        onProyekCreated: ((Proyek) -> Void)? = nil
    ) {
        _viewModel = State(wrappedValue: viewModel)
        self.onProyekCreated = onProyekCreated
    }

    var body: some View {
        VStack(spacing: 0) {
            // Modal Header Bar (X left, Title center, ✓ right)
            modalHeaderBar
                .padding(.horizontal, 20)
                .padding(.top, 16)

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
        }
        .background(sheetBg.ignoresSafeArea())
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

    // MARK: - Header Bar

    private var modalHeaderBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.7))
                    .frame(width: 36, height: 36)
                    .background(Color.black.opacity(0.08))
                    .clipShape(Circle())
            }

            Spacer()

            Text("Tambah Proyek")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(titleColor)

            Spacer()

            Button {
                // Save project and trigger automatic scan via callback
                if let newProyek = viewModel.simpan(in: modelContext) {
                    onProyekCreated?(newProyek)
                    dismiss()
                }
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(viewModel.canSubmit ? oliveGreen : Color.gray.opacity(0.5))
                    .clipShape(Circle())
            }
            .disabled(!viewModel.canSubmit)
        }
    }

    // MARK: - Section Cards

    private var namaAndAirCard: some View {
        cardSection {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Nama Bak")
                        .font(.system(size: 16, weight: .bold))
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
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(titleColor)

                    Spacer()

                    HStack(spacing: 8) {
                        Text("\(viewModel.jumlahKain)")
                            .font(.system(size: 15, weight: .medium))
                            .frame(width: 44, height: 36)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )

                        Text("L")
                            .font(.system(size: 14))
                            .foregroundStyle(titleColor)

                        HStack(spacing: 0) {
                            Button {
                                if viewModel.jumlahKain > 0 { viewModel.jumlahKain -= 1 }
                            } label: {
                                Image(systemName: "minus")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(titleColor)
                                    .frame(width: 36, height: 36)
                            }

                            Divider()
                                .frame(height: 20)

                            Button {
                                viewModel.jumlahKain += 1
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .bold))
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
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(titleColor)

                Spacer()

                if let perangkat = viewModel.perangkat {
                    HStack(spacing: 8) {
                        Image(systemName: "wifi")
                            .foregroundStyle(.gray)

                        Text(perangkat.nama)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.gray)

                        Button {
                            Task { await viewModel.hapusPerangkat() }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 18))
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
                        .font(.system(size: 13, weight: .semibold))
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
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(titleColor)

                if let resep = viewModel.resep {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(resep.namaWarna)
                            .font(.system(size: 14, weight: .semibold))
                            .italic()
                            .foregroundStyle(Color.gray)

                        ZStack(alignment: .trailing) {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(hex: resep.warnaHex))
                                .frame(height: 50)

                            Button {
                                viewModel.hapusResep()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 18))
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
                            .font(.system(size: 15, weight: .semibold))
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
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(titleColor)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "cylinder.split.1x2")
                            .foregroundStyle(titleColor)
                        Text("Kode Pewarna Naphtol")
                            .font(.system(size: 14, weight: .bold))
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
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(titleColor)

                    Spacer()

                    Text("\(resep.air)")
                        .frame(width: 50, height: 32)
                        .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3), lineWidth: 1))

                    Text("L")
                        .font(.system(size: 14))
                        .foregroundStyle(titleColor)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "cylinder.split.1x2")
                            .foregroundStyle(titleColor)
                        Text("Zat Pembantu")
                            .font(.system(size: 14, weight: .bold))
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
                .font(.system(size: 14))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1))

            Spacer()

            HStack(spacing: 6) {
                Text(amount)
                    .frame(width: 50, height: 32)
                    .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3), lineWidth: 1))

                Text(unit)
                    .font(.system(size: 14))
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
