//
//  MulaiPindaiView.swift
//  Serona
//
//  Created by Steffany Florence on 14/11/26.
//

import SwiftData
import SwiftUI

struct MulaiPindaiSheetView: View {
    let proyek: Proyek
    var deviceService: (any DeviceConnecting)? = nil
    var onStartScan: (Proyek) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var formVM: TambahProyekViewModel
    @State private var isShowingDeviceSheet = false
    @State private var isShowingColorSheet = false

    private let alertRed = Color(hex: "#DE2428")

    init(
        proyek: Proyek,
        deviceService: (any DeviceConnecting)? = nil,
        onStartScan: @escaping (Proyek) -> Void
    ) {
        self.proyek = proyek
        self.deviceService = deviceService
        self.onStartScan = onStartScan
        _formVM = State(initialValue: TambahProyekViewModel(service: deviceService))
    }

    var body: some View {
        VStack(spacing: 20) {
            headerBar

            ScrollView {
                VStack(spacing: 16) {
                    perangkatCard
                    warnaCard
                    namaPemesanCard
                    jumlahAirCard
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .background(Color.white.ignoresSafeArea())
        .sheet(isPresented: $isShowingDeviceSheet) {
            HubungkanPerangkatModalView(
                selectedDevice: formVM.perangkat,
                service: deviceService,
                onConnected: { device in
                    formVM.pilihPerangkat(device)
                },
                onDisconnected: {
                    Task { await formVM.hapusPerangkat() }
                }
            )
            .presentationSizing(.fitted)
            .presentationBackground(Color.white)
        }
        .sheet(isPresented: $isShowingColorSheet) {
            PilihWarnaModalView(
                selectedResep: formVM.resep,
                onConfirm: { resep in
                    formVM.pilihResep(resep)
                }
            )
        }
        .alert(
            "Gagal menyimpan proyek",
            isPresented: Binding(
                get: { formVM.saveError != nil },
                set: { if !$0 { formVM.clearSaveError() } }
            ),
            presenting: formVM.saveError
        ) { _ in
            Button("Tutup", role: .cancel) {}
        } message: { error in
            Text(error)
        }
    }

    // MARK: - Top Header Bar

    private var headerBar: some View {
        HStack {
            Button {
                Task {
                    await formVM.hapusPerangkat()
                    dismiss()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .frame(width: 40, height: 40)
                    .background(Color(UIColor.systemGray5))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            Text(proyek.nama)
                .font(.headline.bold())
                .foregroundStyle(.primary)

            Spacer()

            Button {
                if formVM.simpanUntukPindai(proyek, in: modelContext) {
                    dismiss()
                    onStartScan(proyek)
                }
            } label: {
                Image(systemName: "checkmark")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(formVM.canSubmitScan ? Color.oliveGreen : Color.gray.opacity(0.6))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!formVM.canSubmitScan)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }

    // MARK: - Section Cards

    private var perangkatCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let device = formVM.perangkat {
                Text("Perangkat")
                    .font(.headline)
                    .foregroundStyle(.primary)

                HStack(spacing: 8) {
                    Image(systemName: "wifi")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.oliveGreen)

                    Text(device.nama)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.oliveGreen)

                    Spacer()

                    Button {
                        Task { await formVM.hapusPerangkat() }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(alertRed)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                HStack {
                    Text("Perangkat")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Spacer()

                    Button {
                        isShowingDeviceSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text("Hubungkan")
                        }
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.oliveGreen)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    private var warnaCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Warna")
                .font(.headline)
                .foregroundStyle(.primary)

            if let resep = formVM.resep {
                Text(resep.namaWarna)
                    .font(.caption)
                    .italic()
                    .foregroundStyle(.secondary)

                ZStack(alignment: .trailing) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(swatchColor(for: resep))
                        .frame(height: 44)

                    Button {
                        formVM.hapusResep()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.body)
                            .foregroundStyle(.white)
                            .padding(.trailing, 12)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Button {
                    isShowingColorSheet = true
                } label: {
                    Text("Pilih Warna")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.oliveGreen)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    private var namaPemesanCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Nama Pemesan")
                .font(.headline)
                .foregroundStyle(.primary)

            TextField("", text: $formVM.namaPemesan)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .frame(height: 40)
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                )
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    private var jumlahAirCard: some View {
        HStack(spacing: 12) {
            Text("Jumlah Air")
                .font(.headline)
                .foregroundStyle(.primary)

            TextField("0", value: $formVM.jumlahAir, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.subheadline.weight(.medium))
                .frame(width: 64, height: 38)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                )
                .onChange(of: formVM.jumlahAir) { _, newValue in
                    if newValue < 0 {
                        formVM.jumlahAir = 0
                    }
                }

            Text("L")
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer()

            HStack(spacing: 0) {
                Button {
                    if formVM.jumlahAir > 0 {
                        formVM.jumlahAir -= 1
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 40, height: 34)
                }
                .buttonStyle(.plain)

                Divider()
                    .frame(height: 18)

                Button {
                    formVM.jumlahAir += 1
                } label: {
                    Image(systemName: "plus")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.black)
                        .frame(width: 40, height: 34)
                }
                .buttonStyle(.plain)
            }
            .background(Color(UIColor.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    private func swatchColor(for resep: Resep) -> Color {
        if let hex = resep.warnaHex, !hex.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return Color(hex: hex)
        }
        return Color(UIColor.systemGray4)
    }
}

// MARK: - Hubungkan Perangkat Sub-Sheet

private struct HubungkanPerangkatModalView: View {
    let selectedDevice: DiscoveredDevice?
    var onConnected: (DiscoveredDevice) -> Void
    var onDisconnected: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: DeviceListViewModel

    @ScaledMetric(relativeTo: .body) private var fittedSheetWidth: CGFloat = 450
    @ScaledMetric(relativeTo: .body) private var fittedSheetHeight: CGFloat = 395

    private let alertRed = Color(hex: "#DE2428")

    init(
        selectedDevice: DiscoveredDevice?,
        service: (any DeviceConnecting)? = nil,
        onConnected: @escaping (DiscoveredDevice) -> Void,
        onDisconnected: @escaping () -> Void
    ) {
        self.selectedDevice = selectedDevice
        self.onConnected = onConnected
        self.onDisconnected = onDisconnected
        _viewModel = State(initialValue: DeviceListViewModel(service: service))
    }

    private var activeConnectedDevice: DiscoveredDevice? {
        viewModel.connectedDevice ?? selectedDevice
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.white
                    .ignoresSafeArea()

                if viewModel.devices.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Mencari perangkat...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        deviceRows
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }

                if let connecting = viewModel.connectingDevice {
                    connectingOverlay(for: connecting)
                }
            }
            .navigationTitle("Hubungkan Perangkat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.white, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Tutup", systemImage: "xmark") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("Pindai Ulang", systemImage: "arrow.clockwise") {
                        Task { await viewModel.scan() }
                    }
                    .disabled(viewModel.isScanning)
                }
            }
        }
        .frame(
            minWidth: fittedSheetWidth,
            idealWidth: fittedSheetWidth,
            minHeight: fittedSheetHeight,
            idealHeight: fittedSheetHeight
        )
        .background(Color.white)
        .task {
            await viewModel.scan()
        }
        .alert(
            "Koneksi Gagal",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.clearError() } }
            ),
            presenting: viewModel.errorMessage
        ) { _ in
            Button("Tutup", role: .cancel) {}
        } message: { error in
            Text(error)
        }
    }

    private var deviceRows: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.devices) { device in
                deviceRow(for: device)
                    .padding(.horizontal, 20)

                if device.id != viewModel.devices.last?.id {
                    Divider()
                        .padding(.horizontal, 20)
                }
            }
        }
        .padding(.bottom, 8)
        .background(Color.white)
    }

    private func deviceRow(for device: DiscoveredDevice) -> some View {
        let isConnected = activeConnectedDevice?.id == device.id

        return HStack(spacing: 12) {
            Label(device.nama, systemImage: "wifi")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 16)

            if isConnected {
                Button("Putuskan", systemImage: "minus.circle.fill") {
                    Task {
                        await viewModel.disconnect()
                        onDisconnected()
                    }
                }
                .labelStyle(.iconOnly)
                .font(.title3)
                .foregroundStyle(alertRed)
                .buttonStyle(.plain)
            } else {
                Button {
                    Task {
                        await viewModel.connect(device)
                        if let connected = viewModel.connectedDevice, connected.id == device.id {
                            onConnected(connected)
                            dismiss()
                        }
                    }
                } label: {
                    Label("Hubungkan", systemImage: "plus")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .fixedSize()
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
                .tint(Color.oliveGreen)
            }
        }
        .padding(.vertical, 12)
    }

    private func connectingOverlay(for device: DiscoveredDevice) -> some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 10) {
                Text(device.nama)
                    .font(.headline.bold())
                    .foregroundStyle(.primary)

                Text("Menghubungkan...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button {
                    viewModel.cancelConnecting()
                } label: {
                    Text("Batalkan")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .tint(Color.gray)
                .padding(.top, 4)
            }
            .padding()
            .frame(maxWidth: 320)
            .background(Color.white, in: .rect(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.15), radius: 16, x: 0, y: 8)
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Pilih Warna Sub-Sheet

private struct PilihWarnaModalView: View {
    @Query(sort: \Resep.dibuat, order: .reverse) private var daftarResep: [Resep]
    @Environment(\.dismiss) private var dismiss

    @State private var chosenResep: Resep?
    var onConfirm: (Resep) -> Void

    init(selectedResep: Resep?, onConfirm: @escaping (Resep) -> Void) {
        _chosenResep = State(initialValue: selectedResep)
        self.onConfirm = onConfirm
    }

    var body: some View {
        VStack(spacing: 16) {
            headerBar

            if daftarResep.isEmpty {
                ContentUnavailableView(
                    "Belum ada resep warna",
                    systemImage: "paintpalette",
                    description: Text("Tambahkan resep terlebih dahulu di tab Resep Warna.")
                )
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16)
                        ],
                        spacing: 16
                    ) {
                        ForEach(daftarResep) { resep in
                            resepCard(for: resep)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }
        .background(Color.white.ignoresSafeArea())
    }

    private var headerBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .frame(width: 40, height: 40)
                    .background(Color(UIColor.systemGray5))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Pilih Warna")
                .font(.headline.bold())
                .foregroundStyle(.primary)

            Spacer()

            Button {
                if let chosenResep {
                    onConfirm(chosenResep)
                    dismiss()
                }
            } label: {
                Image(systemName: "checkmark")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(chosenResep != nil ? Color.oliveGreen : Color.gray.opacity(0.6))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(chosenResep == nil)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }

    private func resepCard(for resep: Resep) -> some View {
        let isSelected = chosenResep?.persistentModelID == resep.persistentModelID

        return Button {
            chosenResep = resep
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                if let hex = resep.warnaHex, !hex.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: hex))
                        .aspectRatio(1, contentMode: .fit)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(UIColor.systemGray5))
                            .aspectRatio(1, contentMode: .fit)

                        VStack(spacing: 6) {
                            Image(systemName: "photo")
                                .font(.title)
                                .foregroundStyle(Color.gray.opacity(0.75))

                            Text("Warna akan muncul\nsetelah digunakan")
                                .font(.caption2)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                        }
                        .padding(8)
                    }
                }

                Text(resep.namaWarna)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .padding(12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.oliveGreen : Color.clear, lineWidth: 2.5)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Mulai Pindai Sheet", traits: .landscapeLeft) {
    let container = try! SeronaSchema.makeContainer(inMemory: true)
    let context = container.mainContext

    let r1 = Resep(namaWarna: "Merah Bata", warnaHex: "#A63743", air: 1000, kepekatan: 90, batasPH: 11)
    let r2 = Resep(namaWarna: "Ungu Tua", warnaHex: "#933C64", air: 1000, kepekatan: 90, batasPH: 11)
    let r3 = Resep(namaWarna: "Marun", warnaHex: nil, air: 1000, kepekatan: 90, batasPH: 11)
    let r4 = Resep(namaWarna: "Ungu Muda", warnaHex: "#AC4574", air: 1000, kepekatan: 90, batasPH: 11)
    context.insert(r1)
    context.insert(r2)
    context.insert(r3)
    context.insert(r4)

    let bak1 = Proyek(nama: "Bak 1", perangkatNama: "ESP 32", resep: r1, jumlahKain: 1)
    bak1.selesaikan(kepekatanAkhir: nil, phAkhir: nil)
    context.insert(bak1)

    return MulaiPindaiSheetView(
        proyek: bak1,
        deviceService: SimulatedDeviceConnectionService(discoveryDelay: .milliseconds(100), connectionDelay: .seconds(1)),
        onStartScan: { _ in }
    )
    .modelContainer(container)
}
