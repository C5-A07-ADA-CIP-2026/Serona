//
//  ProyekListView.swift
//  Serona
//

import SwiftData
import SwiftUI

struct ProyekRepairTarget: Identifiable {
    let id: UUID
    let proyek: Proyek
    let viewModel: ProyekDetailViewModel
    let issue: QualityIssue
}

struct ProyekQualityAlertTarget: Identifiable {
    let id: UUID
    let proyek: Proyek
    let viewModel: ProyekDetailViewModel
    let alert: QualityAlert
}

struct ProyekListView: View {
    @Query(sort: \Proyek.tanggal, order: .forward) private var semuaProyek: [Proyek]
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ProyekListViewModel()
    @State private var searchText: String = ""

    @State private var activeViewModels: [UUID: ProyekDetailViewModel] = [:]
    @State private var scanSetupTarget: Proyek?
    @State private var activeAlertTarget: ProyekQualityAlertTarget?
    @State private var lastShownAlertTarget: ProyekQualityAlertTarget?
    @State private var queuedAlertTargets: [ProyekQualityAlertTarget] = []
    @State private var pendingRepairTarget: ProyekRepairTarget?
    @State private var repairTarget: ProyekRepairTarget?

    @Binding var newlyCreatedProyek: Proyek?
    
    var serviceProvider: (Proyek) -> (any ColorMeasurementSource)? = { _ in nil }
    var deviceConnectingProvider: () -> (any DeviceConnecting)? = { nil }

    init(
        newlyCreatedProyek: Binding<Proyek?> = .constant(nil),
        serviceProvider: @escaping (Proyek) -> (any ColorMeasurementSource)? = { _ in nil },
        deviceConnectingProvider: @escaping () -> (any DeviceConnecting)? = { nil }
    ) {
        _newlyCreatedProyek = newlyCreatedProyek
        self.serviceProvider = serviceProvider
        self.deviceConnectingProvider = deviceConnectingProvider
    }
    
    private let titleColor = Color("titleColor")
    private let oliveGreen = Color("oliveGreen")

    private var displayedProyek: [Proyek] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return semuaProyek
        }
        return semuaProyek.filter { $0.nama.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        ZStack {
            BackgroundGradient()

            GeometryReader { geometry in
                let isLandscape = geometry.size.width > geometry.size.height
                let columnsCount = isLandscape ? 3 : 2
                let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 20), count: columnsCount)

                VStack(alignment: .leading, spacing: 20) {
                    Text("Bak Warna")
                        .font(.largeTitle.bold())
                        .foregroundStyle(titleColor)
                        .padding(.horizontal, 24)
                        .padding(.top, 12)

                    if displayedProyek.isEmpty {
                        emptyState
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            proyekGridView(columns: gridColumns)
                        }
                    }
                }
            }
        }
        .onAppear {
            resumeAlreadyScannedProjects()
        }
        .onChange(of: displayedProyek.map(\.id)) { _, _ in
            resumeAlreadyScannedProjects()
        }
        .onChange(of: newlyCreatedProyek?.id) { _, _ in
            if let proyek = newlyCreatedProyek {
                newlyCreatedProyek = nil
                startScanAfterSetup(for: proyek)
            }
        }
        .sheet(item: $scanSetupTarget) { targetProyek in
            MulaiPindaiSheetView(
                proyek: targetProyek,
                deviceService: deviceConnectingProvider()
            ) { configuredProyek in
                startScanAfterSetup(for: configuredProyek)
            }
        }
        .sheet(item: $activeAlertTarget, onDismiss: handleAlertDismissed) { target in
            QualityAlertSheetView(alert: target.alert, bakName: target.proyek.nama) {
                pendingRepairTarget = ProyekRepairTarget(
                    id: target.id,
                    proyek: target.proyek,
                    viewModel: target.viewModel,
                    issue: target.alert.issue
                )
            }
        }
        .sheet(item: $repairTarget, onDismiss: showNextQueuedAlertIfNeeded) { target in
            PerbaikiLarutanView(issue: target.issue, viewModel: target.viewModel)
        }
        .alert(
            "Data warna tidak tersedia",
            isPresented: scanErrorIsPresented,
            presenting: activeScanError
        ) { _ in
            Button("Tutup", role: .cancel) {
                clearAllScanErrors()
            }
        } message: { error in
            Text(error)
        }
        .alert(
            "Gagal menyimpan proyek",
            isPresented: isPresented(viewModel.deleteError, clear: viewModel.clearDeleteError),
            presenting: viewModel.deleteError
        ) { _ in
            Button("Tutup", role: .cancel) {}
        } message: { error in
            Text(error)
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image("IconBakWarna")
                .resizable()
                .scaledToFit()
                .frame(width: 110, height: 110)
                .accessibilityHidden(true)

            VStack(spacing: 4) {
                Text("Tidak Ada Bak Warna")
                    .font(.title3.bold())
                    .foregroundStyle(Color(hex: "#B89B8D"))

                Text("Tekan tanda + untuk menambahkan bak")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color(hex: "#B89B8D"))
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
        .padding(.bottom, 48)
    }

    private func proyekGridView(columns: [GridItem]) -> some View {
        LazyVGrid(columns: columns, spacing: 20) {
            ForEach(displayedProyek) { item in
                proyekCardCell(for: item)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    @ViewBuilder
    private func proyekCardCell(for item: Proyek) -> some View {
        let detailVM = getOrMakeViewModel(for: item)

        BakCardView(
            proyek: item,
            viewModel: detailVM,
            onMulaiPindai: {
                scanSetupTarget = item
            },
            onSelesai: {
                finishProyek(proyek: item, viewModel: detailVM)
            },
            onPerbaikiLarutan: {
                let issue = detailVM.qualityAlert?.issue ?? detailVM.currentIssue ?? .keduanya
                repairTarget = ProyekRepairTarget(
                    id: item.id,
                    proyek: item,
                    viewModel: detailVM,
                    issue: issue
                )
            },
            onQualityAlert: { alert in
                handleQualityAlert(for: item, viewModel: detailVM, alert: alert)
            }
        )
    }

    // MARK: - Auto Alert Presentation & Queue

    private func handleQualityAlert(for proyek: Proyek, viewModel: ProyekDetailViewModel, alert: QualityAlert) {
        guard proyek.status == .aktif else { return }

        if repairTarget?.id == proyek.id {
            return
        }

        let target = ProyekQualityAlertTarget(
            id: proyek.id,
            proyek: proyek,
            viewModel: viewModel,
            alert: alert
        )

        if activeAlertTarget?.id == proyek.id {
            activeAlertTarget = target
            lastShownAlertTarget = target
            return
        }

        if activeAlertTarget == nil && repairTarget == nil {
            activeAlertTarget = target
            lastShownAlertTarget = target
        } else if let queuedIndex = queuedAlertTargets.firstIndex(where: { $0.id == proyek.id }) {
            queuedAlertTargets[queuedIndex] = target
        } else {
            queuedAlertTargets.append(target)
        }
    }

    private func handleAlertDismissed() {
        lastShownAlertTarget?.viewModel.clearQualityAlert()
        lastShownAlertTarget = nil

        if let pending = pendingRepairTarget {
            pendingRepairTarget = nil
            repairTarget = pending
        } else {
            showNextQueuedAlertIfNeeded()
        }
    }

    private func showNextQueuedAlertIfNeeded() {
        guard activeAlertTarget == nil, repairTarget == nil, !queuedAlertTargets.isEmpty else { return }
        let next = queuedAlertTargets.removeFirst()
        if next.proyek.status == .aktif {
            activeAlertTarget = next
            lastShownAlertTarget = next
        } else {
            showNextQueuedAlertIfNeeded()
        }
    }

    // MARK: - Scanning & State Lifecycle

    private func getOrMakeViewModel(for proyek: Proyek) -> ProyekDetailViewModel {
        if let existing = activeViewModels[proyek.id] {
            return existing
        }
        let vm = ProyekDetailViewModel(proyek: proyek, service: serviceProvider(proyek))
        activeViewModels[proyek.id] = vm
        return vm
    }

    private func resumeAlreadyScannedProjects() {
        for proyek in displayedProyek where proyek.status == .aktif {
            let vm = getOrMakeViewModel(for: proyek)
            if vm.isDataScanned {
                vm.lanjutkanPengukuran()
            }
        }
    }

    private func startScanAfterSetup(for proyek: Proyek) {
        print("[List] 🚀 startScanAfterSetup \(proyek.nama)")
        queuedAlertTargets.removeAll { $0.id == proyek.id }
        activeViewModels.removeValue(forKey: proyek.id)

        let vm = getOrMakeViewModel(for: proyek)
        Task {
            await vm.mulaiPindaiDenganBaselineAwal(in: modelContext)
        }
    }

    private func finishProyek(proyek: Proyek, viewModel: ProyekDetailViewModel) {
        viewModel.clearQualityAlert()
        viewModel.clearColorConcentrationWarning()
        viewModel.clearWaterPHWarning()

        if activeAlertTarget?.id == proyek.id {
            activeAlertTarget = nil
        }
        queuedAlertTargets.removeAll { $0.id == proyek.id }

        if !viewModel.selesaikan(in: modelContext) {
            viewModel.berhenti()
            proyek.selesaikan(
                kepekatanAkhir: viewModel.latestConcentration,
                phAkhir: viewModel.latestWaterPH
            )
            try? modelContext.save()
        }
        activeViewModels.removeValue(forKey: proyek.id)
    }

    // MARK: - Alert Bindings

    private var activeScanError: String? {
        activeViewModels.values.compactMap(\.colorMeasurementError).first
    }

    private var scanErrorIsPresented: Binding<Bool> {
        Binding(
            get: { activeScanError != nil },
            set: { isPresented in
                if !isPresented { clearAllScanErrors() }
            }
        )
    }

    private func clearAllScanErrors() {
        for vm in activeViewModels.values {
            vm.clearColorMeasurementError()
        }
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

// MARK: - Previews

#Preview("Empty State", traits: .landscapeLeft) {
    NavigationStack {
        ProyekListView()
    }
    .modelContainer(for: SeronaSchema.models, inMemory: true)
}

#Preview("iPad Landscape (3 Stages)", traits: .landscapeLeft) {
    NavigationStack {
        ProyekListView { proyek in
            if proyek.nama == "Bak 3" || proyek.nama == "Bak 5" || proyek.nama == "Bak 6" {
                return ListPreviewMeasurementSource(
                    measurement: ColorMeasurement(visibleAverage: 87, clear: 1000, nir: 100, waterPH: 8)
                )
            }
            return ListPreviewMeasurementSource(
                measurement: ColorMeasurement(visibleAverage: 95, clear: 1000, nir: 100, waterPH: 12)
            )
        }
    }
    .modelContainer(previewGridContainer)
}

#Preview("iPad Portrait (2 Columns)", traits: .portrait) {
    NavigationStack {
        ProyekListView { proyek in
            if proyek.nama == "Bak 3" || proyek.nama == "Bak 5" || proyek.nama == "Bak 6" {
                return ListPreviewMeasurementSource(
                    measurement: ColorMeasurement(visibleAverage: 87, clear: 1000, nir: 100, waterPH: 8)
                )
            }
            return ListPreviewMeasurementSource(
                measurement: ColorMeasurement(visibleAverage: 95, clear: 1000, nir: 100, waterPH: 12)
            )
        }
    }
    .modelContainer(previewGridContainer)
}

private struct ListPreviewMeasurementSource: ColorMeasurementSource {
    let measurement: ColorMeasurement

    func readInitialColorMeasurement() async throws -> ColorMeasurement {
        measurement
    }

    func measurementUpdates() -> AsyncStream<ColorMeasurement> {
        AsyncStream { continuation in
            continuation.yield(measurement)
        }
    }
}

// MARK: - Sample Data Container

@MainActor
private let previewGridContainer: ModelContainer = {
    let container = try! SeronaSchema.makeContainer(inMemory: true)
    let context = container.mainContext

    let resepMaroon = Resep(
        namaWarna: "Merah Maroon", warnaHex: "#7A1C33",
        air: 1000, kepekatan: 80, batasPH: 7
    )
    let resepKrem = Resep(
        namaWarna: "Krem", warnaHex: "#EB9675",
        air: 1000, kepekatan: 80, batasPH: 7
    )
    let resepUnguAbu = Resep(
        namaWarna: "Ungu Abu", warnaHex: "#6B4F69",
        air: 1000, kepekatan: 80, batasPH: 7
    )

    // Bak 1: Stage 1 (Active - Good Quality)
    let bak1 = Proyek(nama: "Bak 1", perangkatNama: "Bu Fanny", resep: resepMaroon, jumlahKain: 2, tanggal: .now.addingTimeInterval(1))
    bak1.visibleAverageAwal = 100
    bak1.phAwal = 12
    context.insert(bak1)

    // Bak 2: Stage 3 (Inactive / Unscanned)
    let bak2 = Proyek(nama: "Bak 2", perangkatNama: "ESP 32", resep: resepMaroon, jumlahKain: 1, tanggal: .now.addingTimeInterval(2))
    bak2.selesaikan(kepekatanAkhir: nil, phAkhir: nil)
    context.insert(bak2)

    // Bak 3: Stage 2 (Active Warning)
    let bak3 = Proyek(nama: "Bak 3", perangkatNama: "Bu Fanny", resep: resepKrem, jumlahKain: 3, tanggal: .now.addingTimeInterval(3))
    bak3.visibleAverageAwal = 100
    bak3.phAwal = 8
    context.insert(bak3)

    // Bak 4: Stage 1 (Active - Good Quality)
    let bak4 = Proyek(nama: "Bak 4", perangkatNama: "Bu Fanny", resep: resepUnguAbu, jumlahKain: 2, tanggal: .now.addingTimeInterval(4))
    bak4.visibleAverageAwal = 100
    bak4.phAwal = 12
    context.insert(bak4)

    // Bak 5: Stage 2 (Active Warning)
    let bak5 = Proyek(nama: "Bak 5", perangkatNama: "Bu Fanny", resep: resepKrem, jumlahKain: 2, tanggal: .now.addingTimeInterval(5))
    bak5.visibleAverageAwal = 100
    bak5.phAwal = 8
    context.insert(bak5)

    // Bak 6: Stage 3 (Inactive / Unscanned)
    let bak6 = Proyek(nama: "Bak 6", perangkatNama: "ESP 32", resep: resepKrem, jumlahKain: 2, tanggal: .now.addingTimeInterval(6))
    bak6.selesaikan(kepekatanAkhir: nil, phAkhir: nil)
    context.insert(bak6)

    return container
}()
