//
//  TambahProyekView.swift
//  Serona
//

import SwiftData
import SwiftUI

struct TambahProyekView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @Query(sort: \Proyek.tanggal, order: .forward) private var semuaProyek: [Proyek]

    @State var viewModel: TambahProyekViewModel
    @State private var isShowingDeviceList = false
    @State private var isShowingPilihResep = false
    @State var saveErrorMessage: String?

    var existingProyek: Proyek?
    var bakTitleOverride: String?
    var deviceService: (any DeviceConnecting)?
    var onProyekCreated: ((Proyek) -> Void)?

    private let oliveGreen = Color("oliveGreen")
    private let alertRed = Color(hex: "#DE2428")
    private let maxBakCount = 6

    init(
        existingProyek: Proyek? = nil,
        bakTitle: String? = nil,
        deviceService: (any DeviceConnecting)? = nil,
        viewModel: TambahProyekViewModel = TambahProyekViewModel(),
        onProyekCreated: ((Proyek) -> Void)? = nil
    ) {
        self.existingProyek = existingProyek
        bakTitleOverride = bakTitle
        self.deviceService = deviceService
        _viewModel = State(wrappedValue: viewModel)
        self.onProyekCreated = onProyekCreated
    }

    var resolvedBakTitle: String {
        if let existingProyek {
            return existingProyek.nama
        }
        if let bakTitleOverride, !bakTitleOverride.isEmpty {
            return bakTitleOverride
        }
        let existingNames = Set(semuaProyek.map(\.nama))
        let nextIndex = (1 ... maxBakCount).first { !existingNames.contains("Bak \($0)") } ?? (semuaProyek.count + 1)
        return "Bak \(nextIndex)"
    }

    var canSubmit: Bool {
        viewModel.canSubmitScan
    }

    var body: some View {
        NavigationStack {
            formContent
                // The bar stays visible on the root so pushing a screen never toggles it from hidden to
                // visible; that toggle made the pushed header start too high and snap down inside the sheet.
                .navigationTitle(resolvedBakTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { headerToolbar }
                .navigationDestination(isPresented: $isShowingDeviceList) { deviceListScreen }
                .navigationDestination(isPresented: $isShowingPilihResep) { pilihWarnaScreen }
        }
        .modalSheetStyle()
        .alert(
            "Gagal menyimpan proyek",
            isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: {
                    if !$0 {
                        saveErrorMessage = nil
                    }
                }
            ),
            presenting: saveErrorMessage
        ) { _ in
            Button("Tutup", role: .cancel) {}
        } message: { error in
            Text(error)
        }
    }

    private var deviceListScreen: some View {
        DeviceListSheetView(
            service: deviceService,
            assignedDeviceIDs: Set(
                semuaProyek.compactMap { proyek in
                    guard proyek.status == .aktif, proyek.id != existingProyek?.id else { return nil }
                    return proyek.perangkatID
                }
            ),
            isPushed: true,
            onConnected: { viewModel.pilihPerangkat($0) },
            onDisconnected: { _ in Task { await viewModel.hapusPerangkat() } }
        )
    }

    private var pilihWarnaScreen: some View {
        PilihWarnaSheetView(selectedResep: viewModel.resep, isPushed: true) {
            viewModel.pilihResep($0)
        }
    }

    private var formContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                perangkatCard
                warnaCard
                namaPemesanCard
                jumlahAirCard
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.interactively)
        .background(Color.white)
    }

    // MARK: - Navigation Bar

    @ToolbarContentBuilder
    private var headerToolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Tutup", systemImage: "xmark") {
                Task {
                    await viewModel.hapusPerangkat()
                    dismiss()
                }
            }
            .labelStyle(.iconOnly)
        }

        ToolbarItem(placement: .confirmationAction) {
            Button("Simpan Proyek", systemImage: "checkmark") {
                simpanProyek()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderedProminent)
            .tint(oliveGreen)
            .disabled(!canSubmit)
        }
    }
}

extension TambahProyekView {
    // MARK: - Section Cards

    private var perangkatCard: some View {
        cardSection {
            if let perangkat = viewModel.perangkat {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Perangkat")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    HStack(spacing: 8) {
                        Image(systemName: "wifi")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.oliveGreenText)

                        Text(perangkat.nama)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.oliveGreenText)

                        Spacer()

                        Button {
                            Task { await viewModel.hapusPerangkat() }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(alertRed)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Putuskan Perangkat")
                    }
                }
            } else {
                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                    : AnyLayout(HStackLayout())
                layout {
                    Text("Perangkat")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    if !dynamicTypeSize.isAccessibilitySize {
                        Spacer()
                    }

                    Button {
                        isShowingDeviceList = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text("Hubungkan")
                        }
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .background(oliveGreen)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var warnaCard: some View {
        cardSection {
            VStack(alignment: .leading, spacing: 10) {
                Text("Warna")
                    .font(.headline)
                    .foregroundStyle(.primary)

                if let resep = viewModel.resep {
                    Text(resep.namaWarna)
                        .font(.caption)
                        .italic()
                        .foregroundStyle(.secondary)

                    ZStack(alignment: .trailing) {
                        WarnaKotak(hex: resep.warnaHex, cornerRadius: 12, iconSize: 22, isCompact: true)
                            .frame(minHeight: 44)

                        Button {
                            viewModel.hapusResep()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.body)
                                // White disappears on the light gray placeholder, so use gray there.
                                .foregroundStyle(Color(hex: resep.warnaHex) == nil ? Color.gray : Color.white)
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Hapus Warna")
                    }
                } else {
                    Button {
                        isShowingPilihResep = true
                    } label: {
                        Text("Pilih Warna")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(oliveGreen)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var namaPemesanCard: some View {
        cardSection {
            VStack(alignment: .leading, spacing: 10) {
                Text("Nama Pemesan")
                    .font(.headline)
                    .foregroundStyle(.primary)

                TextField("", text: $viewModel.namaPemesan)
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                    .background(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                            .allowsHitTesting(false)
                    )
            }
        }
    }

    private var jumlahAirCard: some View {
        cardSection {
            HStack(spacing: 12) {
                Text("Jumlah Air")
                    .font(.headline)
                    .foregroundStyle(.primary)

                TextField("0", value: $viewModel.jumlahAir, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.subheadline.weight(.medium))
                    .monospacedDigit()
                    .frame(width: 64, height: 38)
                    .contentShape(Rectangle())
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                            .allowsHitTesting(false)
                    )
                    .onChange(of: viewModel.jumlahAir) { _, newValue in
                        if newValue < 0 {
                            viewModel.jumlahAir = 0
                        }
                    }

                Text("L")
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                Spacer()

                HStack(spacing: 0) {
                    Button {
                        if viewModel.jumlahAir > 0 {
                            viewModel.jumlahAir -= 1
                        }
                    } label: {
                        Image(systemName: "minus")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Kurangi Air")

                    Divider()
                        .frame(height: 18)

                    Button {
                        viewModel.jumlahAir += 1
                    } label: {
                        Image(systemName: "plus")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.black)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Tambah Air")
                }
                .background(Color(UIColor.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func cardSection(@ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading) {
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}
