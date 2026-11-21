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
    @State var saveErrorMessage: String?
    @FocusState private var isNamaPemesanFocused: Bool

    var existingProyek: Proyek?
    var bakTitleOverride: String?
    var deviceService: (any DeviceConnecting)?
    var onProyekCreated: ((Proyek) -> Void)?

    private let oliveGreen = Color("oliveGreen")
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
            connectedDevice: viewModel.perangkat,
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

    /// A native grouped `Form`: system rows, row height, separators, chevrons and Dynamic Type behavior.
    private var formContent: some View {
        Form {
            // One section per row gives the separate rounded rows of the design without custom drawing.
            Section {
                NavigationLink {
                    deviceListScreen
                } label: {
                    LabeledContent("Perangkat", value: viewModel.perangkat?.nama ?? "")
                }
            }

            Section {
                NavigationLink {
                    pilihWarnaScreen
                } label: {
                    LabeledContent("Warna", value: viewModel.resep?.namaWarna ?? "")
                }
            }

            Section {
                LabeledContent("Nama Pemesan") {
                    TextField("", text: $viewModel.namaPemesan)
                        .multilineTextAlignment(.trailing)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .focused($isNamaPemesanFocused)
                        .accessibilityLabel("Nama Pemesan")
                }
                .contentShape(Rectangle())
                .onTapGesture { isNamaPemesanFocused = true }
            }

            Section {
                Stepper(value: $viewModel.jumlahAir, in: 0 ... Int.max) {
                    LabeledContent("Jumlah Air", value: "\(viewModel.jumlahAir) Liter")
                }
            }
        }
        .listSectionSpacing(12)
        .contentMargins(.top, 8, for: .scrollContent)
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.interactively)
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
