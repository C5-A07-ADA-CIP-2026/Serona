//
//  ProyekDetailView.swift
//  Serona
//

import SwiftData
import SwiftUI

/// One project: its device, color and recipe, and the scan that finishes it.
struct ProyekDetailView: View {
    @State private var isShowingKonfirmasiSelesai = false
    @State private var isMemulai = false
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel: ProyekDetailViewModel
    @Bindable private var proyek: Proyek
    @State private var isShowingDeviceList = false
    @State private var isShowingQualityAlert = false
    @State private var pendingPerbaiki: QualityIssue?
    @State private var perbaikiIssue: QualityIssue?

    init(proyek: Proyek, service: (any ColorMeasurementSource)? = nil) {
        self.proyek = proyek
        _viewModel = StateObject(wrappedValue: ProyekDetailViewModel(proyek: proyek, service: service))
    }

    var body: some View {
        withSheets
            .alert(
                "Data warna tidak tersedia",
                isPresented: isPresented(viewModel.colorMeasurementError, clear: viewModel.clearColorMeasurementError),
                presenting: viewModel.colorMeasurementError
            ) { _ in
                Button("Sambungkan Ulang") {
                    isShowingDeviceList = true
                }
                Button("Tutup", role: .cancel) {}
            } message: { error in
                Text(error)
            }
            .alert(
                "Gagal menyimpan proyek",
                isPresented: isPresented(viewModel.saveError, clear: viewModel.clearSaveError),
                presenting: viewModel.saveError
            ) { _ in
                Button("Tutup", role: .cancel) {}
            } message: { error in
                Text(error)
            }
            .alert("Selesaikan Proyek?", isPresented: $isShowingKonfirmasiSelesai) {
                Button("Batal", role: .cancel) {}
                Button("Selesaikan") {
                    viewModel.selesaikan(in: modelContext)
                }
            } message: {
                Text("Setelah selesai, proyek tidak bisa dipindai atau diubah lagi.")
            }
    }

    private var withSheets: some View {
        screen
            .sheet(isPresented: $isShowingDeviceList) {
                DeviceListSheetView { device in
                    Task { await viewModel.pindahPerangkat(device, in: modelContext) }
                }
            }
            .onChange(of: viewModel.qualityAlert) { _, alert in
                if alert != nil, perbaikiIssue == nil, !isShowingQualityAlert {
                    tampilkanQualityAlert()
                }
            }
            .sheet(isPresented: $isShowingQualityAlert, onDismiss: perbaikiSetelahAlert) {
                if let alert = viewModel.qualityAlert {
                    QualityAlertSheetView(alert: alert) { pendingPerbaiki = alert.issue }
                }
            }
            .sheet(item: $perbaikiIssue) { issue in
                PerbaikiLarutanView(issue: issue, viewModel: viewModel)
            }
    }

    private var screen: some View {
        VStack(spacing: 16) {
            ScrollView {
                details
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if proyek.status == .aktif {
                primaryButton
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .navigationTitle(proyek.nama)
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if isMemulai {
                MemulaiPemindaianOverlay()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isMemulai)
        .onAppear {
            viewModel.lanjutkanPengukuran()
        }
        .onDisappear {
            viewModel.berhenti()
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 24) {
            PerangkatBaris(nama: proyek.perangkatNama)

            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    JudulBagian(teks: "Warna")
                    Spacer()
                    if isLarutanMenurun {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(Color.peringatan)
                            .accessibilityLabel("Kualitas larutan menurun")
//                        Button {
//                            viewModel.tampilkanQualityAlert()
//                        } label: {
//                            Image(systemName: "exclamationmark.circle.fill")
//                                .foregroundStyle(Color.peringatan)
//                        }
//                        .accessibilityLabel("Kualitas larutan menurun")
//                        .accessibilityHint("Menampilkan peringatan")
                    }
                }
                WarnaSwatchView(namaWarna: proyek.namaWarna, warnaHex: proyek.warnaHex)
            }

            if proyek.status == .nonaktif {
                hasilAkhir
            } else if viewModel.isDataScanned, !isMemulai {
                PengukuranSectionView(viewModel: viewModel) { perbaikiIssue = $0 }
            }

            ResepWarnaView(
                pewarna: proyek.pewarna,
                zatPembantu: proyek.zatPembantu,
                air: proyek.air > 0 ? proyek.air : nil
            )

            BarisInfo(judul: "Jumlah Kain", nilai: "\(proyek.jumlahKain)", tebal: true)
        }
    }

    private var isLarutanMenurun: Bool {
        !isMemulai && (viewModel.isConcentrationLow || viewModel.isWaterPHLow)
    }

    private var hasilAkhir: some View {
        VStack(alignment: .leading, spacing: 16) {
            JudulBagian(teks: "Hasil Akhir")
            BarisInfo(
                judul: "Kepekatan Warna Akhir",
                nilai: proyek.kepekatanAkhir.map(Self.persen) ?? "—",
                tebal: true
            )
            BarisInfo(
                judul: "Batas Kepekatan Warna",
                nilai: "\(ProyekColorMeasurements.format(proyek.batasKepekatan))%"
            )
            BarisInfo(
                judul: "pH Air Akhir",
                nilai: proyek.phAkhir.map { ProyekColorMeasurements.format($0) } ?? "—",
                tebal: true
            )
            BarisInfo(judul: "Batas pH", nilai: ProyekColorMeasurements.format(proyek.batasPH))
        }
    }

    /// Clears the alert; when the user chose "Perbaiki Larutan", opens the guide now that the sheet is gone.
    private func perbaikiSetelahAlert() {
        viewModel.clearQualityAlert()
        perbaikiIssue = pendingPerbaiki
        pendingPerbaiki = nil
    }

    /// Shows the sheet as soon as the loading is gone and the readings are on screen.
    private func tampilkanQualityAlert() {
        Task {
            while isMemulai {
                try? await Task.sleep(for: .milliseconds(100))
            }
            if viewModel.qualityAlert != nil {
                isShowingQualityAlert = true
            }
        }
    }

    private func mulai() {
        guard !isMemulai else { return }
        isMemulai = true
        Task {
            async let minimum: Void = Task.sleep(for: .seconds(1.5))
            await viewModel.mulaiPindai()
            guard viewModel.colorMeasurementError == nil else {
                isMemulai = false
                return
            }
            try? await minimum
            isMemulai = false
        }
    }

    private var primaryButton: some View {
        Button {
            if viewModel.isDataScanned {
                isShowingKonfirmasiSelesai = true
            } else {
                mulai()
            }
        } label: {
            HStack(spacing: 8) {
                if viewModel.isScanning {
                    ProgressView()
                        .controlSize(.small)
                } else if !viewModel.isDataScanned {
                    Image(systemName: "plus")
                }
                Text(primaryButtonTitle)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(viewModel.isScanning ? "Memindai data" : primaryButtonTitle)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(viewModel.isScanning)
    }

    private static func persen(_ value: Double) -> String {
        String(format: "%.1f%%", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    private var primaryButtonTitle: String {
        viewModel.isDataScanned ? "Selesaikan Proyek" : "Mulai Pindai"
    }

    private func isPresented(_ value: (some Any)?, clear: @escaping () -> Void) -> Binding<Bool> {
        Binding(
            get: { value != nil },
            set: { isPresented in
                if !isPresented {
                    DispatchQueue.main.async { clear() }
                }
            }
        )
    }
}

/// Shown over the project while the first scan reads the device.
private struct MemulaiPemindaianOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)

                Text("Memulai pemindaian…")
                    .font(.headline)

                Text("Pastikan perangkat tetap menyala dan terhubung.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .frame(maxWidth: 280)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            .accessibilityElement(children: .combine)
        }
    }
}

#Preview("Aktif") {
    NavigationStack {
        ProyekDetailView(proyek: .previewSample, service: SimulatedDeviceConnectionService())
    }
}

#Preview("Accessibility size") {
    NavigationStack {
        ProyekDetailView(proyek: .previewSample, service: SimulatedDeviceConnectionService())
    }
    .dynamicTypeSize(.accessibility5)
}

#Preview("Nonaktif") {
    let proyek = Proyek.previewSample
    proyek.selesaikan(kepekatanAkhir: 94.04, phAkhir: 9)
    return NavigationStack {
        ProyekDetailView(proyek: proyek, service: SimulatedDeviceConnectionService())
    }
}

/// Reads full color and pH 12 at first, then `reading`, to try the quality alert.
private struct LowReadingPreviewSource: ColorMeasurementSource {
    let reading: ColorMeasurement

    func readInitialColorMeasurement() async throws -> ColorMeasurement {
        ColorMeasurement(visibleAverage: 1000, clear: 1000, nir: 100, waterPH: 12)
    }

    func measurementUpdates() -> AsyncStream<ColorMeasurement> {
        AsyncStream { continuation in
            continuation.yield(reading)
        }
    }
}

#Preview("Kepekatan saja di bawah batas") {
    NavigationStack {
        ProyekDetailView(
            proyek: .previewSample,
            service: LowReadingPreviewSource(
                reading: ColorMeasurement(visibleAverage: 500, clear: 1000, nir: 100, waterPH: 12)
            )
        )
    }
}

#Preview("pH saja di bawah batas") {
    NavigationStack {
        ProyekDetailView(
            proyek: .previewSample,
            service: LowReadingPreviewSource(
                reading: ColorMeasurement(visibleAverage: 1000, clear: 1000, nir: 100, waterPH: 1)
            )
        )
    }
}

#Preview("Kepekatan dan pH di bawah batas") {
    NavigationStack {
        ProyekDetailView(
            proyek: .previewSample,
            service: LowReadingPreviewSource(
                reading: ColorMeasurement(visibleAverage: 500, clear: 1000, nir: 100, waterPH: 1)
            )
        )
    }
}
