//
//  TambahProyekView.swift
//  Serona
//

import SwiftData
import SwiftUI

struct TambahProyekView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Proyek.tanggal, order: .forward) private var semuaProyek: [Proyek]

    @State private var viewModel: TambahProyekViewModel
    @State private var isShowingDeviceList = false
    @State private var isShowingPilihResep = false
    @State private var saveErrorMessage: String?

    @ScaledMetric(relativeTo: .body) private var sheetWidth: CGFloat = 450

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
        self.bakTitleOverride = bakTitle
        self.deviceService = deviceService
        _viewModel = State(wrappedValue: viewModel)
        self.onProyekCreated = onProyekCreated
    }

    private var resolvedBakTitle: String {
        if let existingProyek {
            return existingProyek.nama
        }
        if let bakTitleOverride, !bakTitleOverride.isEmpty {
            return bakTitleOverride
        }
        let existingNames = Set(semuaProyek.map(\.nama))
        let nextIndex = (1...maxBakCount).first { !existingNames.contains("Bak \($0)") } ?? (semuaProyek.count + 1)
        return "Bak \(nextIndex)"
    }

    private var canSubmit: Bool {
        viewModel.canSubmitScan
    }

    var body: some View {
        VStack(spacing: 20) {
            headerBar

            VStack(spacing: 16) {
                perangkatCard
                warnaCard
                namaPemesanCard
                jumlahAirCard
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(width: sheetWidth)
        .background(Color.white)
        .presentationSizing(.fitted)
        .presentationBackground(Color.white)
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $isShowingDeviceList) {
            DeviceListSheetView(
                service: deviceService,
                onConnected: { viewModel.pilihPerangkat($0) },
                onDisconnected: { _ in Task { await viewModel.hapusPerangkat() } }
            )
        }
        .sheet(isPresented: $isShowingPilihResep) {
            PilihWarnaSheetView(selectedResep: viewModel.resep) {
                viewModel.pilihResep($0)
            }
        }
        .alert(
            "Gagal menyimpan proyek",
            isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { if !$0 { saveErrorMessage = nil } }
            ),
            presenting: saveErrorMessage
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
                    await viewModel.hapusPerangkat()
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
            .accessibilityLabel("Tutup")

            Spacer()

            Text(resolvedBakTitle)
                .font(.headline.bold())
                .foregroundStyle(.primary)

            Spacer()

            Button {
                simpanProyek()
            } label: {
                Image(systemName: "checkmark")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(canSubmit ? oliveGreen : Color.gray.opacity(0.65))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit)
            .accessibilityLabel("Simpan Proyek")
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
    }

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
                            .foregroundStyle(oliveGreen)

                        Text(perangkat.nama)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(oliveGreen)

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
                HStack {
                    Text("Perangkat")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Spacer()

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
                        .padding(.vertical, 8)
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
                        WarnaKotak(hex: resep.warnaHex, cornerRadius: 12, iconSize: 22)
                            .frame(height: 44)

                        Button {
                            viewModel.hapusResep()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.body)
                                .foregroundStyle(.white)
                                .padding(.trailing, 12)
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
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
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
                    .frame(height: 40)
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
                            .frame(width: 40, height: 34)
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
                            .frame(width: 40, height: 34)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Tambah Air")
                }
                .background(Color(UIColor.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func cardSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading) {
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    // MARK: - Save Action

    private func simpanProyek() {
        guard canSubmit, let resep = viewModel.resep else { return }
        let trimmedPemesan = viewModel.namaPemesan.trimmingCharacters(in: .whitespacesAndNewlines)
        let airLiter = viewModel.jumlahAir > 0 ? viewModel.jumlahAir : resep.air

        if let existingProyek {
            existingProyek.perangkatNama = trimmedPemesan
            existingProyek.resep = resep
            existingProyek.namaWarna = resep.namaWarna
            existingProyek.warnaHex = resep.warnaHex
            existingProyek.pewarna = resep.pewarna
            existingProyek.zatPembantu = resep.zatPembantu
            existingProyek.airResepTersimpan = resep.air
            existingProyek.jumlahKain = 1
            existingProyek.tanggal = .now
            existingProyek.status = .aktif
//            existingProyek.tanggalSelesai = nil
            existingProyek.visibleAverageAwal = nil
            existingProyek.rasioAwal = nil
            existingProyek.phAwal = nil
            existingProyek.kepekatanAkhir = nil
            existingProyek.phAkhir = nil
            existingProyek.batasKepekatan = ProyekDetailViewModel.defaultConcentrationLimit
            existingProyek.batasPH = ProyekDetailViewModel.defaultWaterPHLimit
            existingProyek.air = airLiter
            existingProyek.rasioAirBersih = ProyekDetailViewModel.defaultCleanWaterRatios

            do {
                try modelContext.save()
                onProyekCreated?(existingProyek)
                dismiss()
            } catch {
                saveErrorMessage = "Gagal menyimpan proyek: \(error.localizedDescription)"
            }
            return
        }

        let newProyek = Proyek(
            nama: resolvedBakTitle,
            perangkatNama: trimmedPemesan,
            resep: resep,
            jumlahKain: 1,
            tanggal: .now
        )
        newProyek.batasKepekatan = ProyekDetailViewModel.defaultConcentrationLimit
        newProyek.batasPH = ProyekDetailViewModel.defaultWaterPHLimit
        newProyek.air = airLiter
        newProyek.rasioAirBersih = ProyekDetailViewModel.defaultCleanWaterRatios

        modelContext.insert(newProyek)
        do {
            try modelContext.save()
            onProyekCreated?(newProyek)
            dismiss()
        } catch {
            modelContext.delete(newProyek)
            saveErrorMessage = "Gagal menyimpan proyek: \(error.localizedDescription)"
        }
    }
}

// MARK: - Pilih Warna Sub-Sheet

private struct PilihWarnaSheetView: View {
    @Query(sort: \Resep.dibuat, order: .reverse) private var daftarResep: [Resep]
    @Environment(\.dismiss) private var dismiss

    @State private var chosenResep: Resep?
    @ScaledMetric(relativeTo: .body) private var sheetWidth: CGFloat = 460

    var onConfirm: (Resep) -> Void

    private let oliveGreen = Color("oliveGreen")

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
                    image: "IconResepWarna",
                    description: Text("Tambahkan resep terlebih dahulu di tab Resep Warna.")
                )
                .foregroundColor(Color(hex: "#B89B8D"))
                .frame(minHeight: 360)
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 20),
                            GridItem(.flexible(), spacing: 20),
                        ],
                        spacing: 20
                    ) {
                        ForEach(daftarResep) { resep in
                            resepCard(for: resep)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 4)
                    .padding(.bottom, 24)
                }
                .frame(minHeight: 440, maxHeight: 520)
            }
        }
        .frame(width: sheetWidth)
        .background(Color.white)
        .presentationSizing(.fitted)
        .presentationBackground(Color.white)
        .presentationDragIndicator(.visible)
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
            .accessibilityLabel("Tutup")

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
                    .background(chosenResep != nil ? oliveGreen : Color.gray.opacity(0.6))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(chosenResep == nil)
            .accessibilityLabel("Konfirmasi Warna")
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
    }

    private func resepCard(for resep: Resep) -> some View {
        let isSelected = chosenResep?.persistentModelID == resep.persistentModelID

        return Button {
            chosenResep = resep
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                if let hex = resep.warnaHex, !hex.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: hex))
                        .aspectRatio(1, contentMode: .fit)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(UIColor.systemGray5))
                            .aspectRatio(1, contentMode: .fit)

                        VStack(spacing: 8) {
                            Image(systemName: "photo")
                                .font(.system(size: 36))
                                .foregroundStyle(Color.gray.opacity(0.75))

                            Text("Warna akan muncul\nsetelah digunakan")
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(Color.gray)
                        }
                        .padding(8)
                    }
                }

                Text(resep.namaWarna)
                    .font(.headline.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .padding(14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isSelected ? oliveGreen : Color.clear, lineWidth: 2.5)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#Preview("Tambah Proyek Sheet", traits: .landscapeLeft) {
    BackgroundGradient()
        .sheet(isPresented: .constant(true)) {
            TambahProyekView(bakTitle: "Bak 1")
        }
        .modelContainer(for: SeronaSchema.models, inMemory: true)
}

#Preview("Pilih Warna Sheet", traits: .landscapeLeft) {
    let container = try! SeronaSchema.makeContainer(inMemory: true)
    let context = container.mainContext

    context.insert(Resep(namaWarna: "Ungu Muda", warnaHex: "#AC4574", air: 1000, kepekatan: 90, batasPH: 11, dibuat: .now.addingTimeInterval(1)))
    context.insert(Resep(namaWarna: "Marun", warnaHex: nil, air: 1000, kepekatan: 90, batasPH: 11, dibuat: .now.addingTimeInterval(2)))
    context.insert(Resep(namaWarna: "Ungu Tua", warnaHex: "#933C64", air: 1000, kepekatan: 90, batasPH: 11, dibuat: .now.addingTimeInterval(3)))
    context.insert(Resep(namaWarna: "Merah Bata", warnaHex: "#A63743", air: 1000, kepekatan: 90, batasPH: 11, dibuat: .now.addingTimeInterval(4)))

    return BackgroundGradient()
        .sheet(isPresented: .constant(true)) {
            PilihWarnaSheetView(selectedResep: nil) { _ in }
        }
        .modelContainer(container)
}
