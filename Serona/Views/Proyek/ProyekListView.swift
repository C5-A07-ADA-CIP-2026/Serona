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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query(sort: \Proyek.tanggal, order: .forward) private var semuaProyek: [Proyek]
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ProyekListViewModel()
    @State private var searchText: String = ""

    /// Owned by the app root, so measurements keep running while this view is not on screen.
    let store: ProyekMeasurementStore
    @State private var scanSetupTarget: Proyek?
    @State private var deviceSwitchTarget: Proyek?
    @State private var activeAlertTarget: ProyekQualityAlertTarget?
    @State private var lastShownAlertTarget: ProyekQualityAlertTarget?
    @State private var queuedAlertTargets: [ProyekQualityAlertTarget] = []
    @State private var pendingRepairTarget: ProyekRepairTarget?
    @State private var repairTarget: ProyekRepairTarget?

    @Binding var newlyCreatedProyek: Proyek?

    var serviceProvider: (Proyek) -> (any ColorMeasurementSource)? = { _ in nil }
    var deviceConnectingProvider: () -> (any DeviceConnecting)? = { nil }

    init(
        store measurementStore: ProyekMeasurementStore = ProyekMeasurementStore(),
        newlyCreatedProyek: Binding<Proyek?> = .constant(nil),
        serviceProvider: @escaping (Proyek) -> (any ColorMeasurementSource)? = { _ in nil },
        deviceConnectingProvider: @escaping () -> (any DeviceConnecting)? = { nil }
    ) {
        store = measurementStore
        _newlyCreatedProyek = newlyCreatedProyek
        self.serviceProvider = serviceProvider
        self.deviceConnectingProvider = deviceConnectingProvider
    }

    private let titleColor = Color("titleColor")
    private let oliveGreen = Color("oliveGreen")

    private var displayedProyek: [Proyek] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return semuaProyek.diurutkanAbjad()
        }
        return semuaProyek.filter { $0.nama.localizedCaseInsensitiveContains(searchText) }.diurutkanAbjad()
    }

    var body: some View {
        ZStack {
            BackgroundGradient()

            GeometryReader { geometry in
                let gridColumns = Self.gridColumns(
                    forWidth: geometry.size.width, singleColumn: dynamicTypeSize.isAccessibilitySize
                )
                let sidePadding = AdaptiveLayout.sidePadding(forWidth: geometry.size.width)

                VStack(alignment: .leading, spacing: 20) {
                    Text("Bak Warna")
                        .font(.largeTitle.bold())
                        .foregroundStyle(titleColor)
                        .padding(.horizontal, sidePadding)
                        .padding(.top, 12)

                    if displayedProyek.isEmpty {
                        emptyState
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            proyekGridView(columns: gridColumns, sidePadding: sidePadding)
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
        .sheet(item: $deviceSwitchTarget) { targetProyek in
            DeviceListSheetView(
                service: deviceConnectingProvider(),
                assignedDeviceIDs: Set(
                    semuaProyek.compactMap { proyek in
                        guard proyek.status == .aktif, proyek.id != targetProyek.id else { return nil }
                        return proyek.perangkatID
                    }
                ),
                onConnected: { device in
                    switchDeviceAndReconnect(for: targetProyek, to: device)
                }
            )
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
        ) { errorInfo in
            if let failedProyek = errorInfo.proyek, failedProyek.status == .aktif {
                Button("Pilih Perangkat Lain") {
                    clearAllScanErrors()
                    deviceSwitchTarget = failedProyek
                }
            }
            Button("Tutup", role: .cancel) {
                clearAllScanErrors()
            }
        } message: { errorInfo in
            Text(errorInfo.message)
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

    /// One column on a phone, two or three on an iPad, so a card is never narrower than 320 pt.
    private static func gridColumns(forWidth width: CGFloat, singleColumn: Bool) -> [GridItem] {
        AdaptiveLayout.gridColumns(
            forWidth: width, minimumItemWidth: 320, spacing: 20, limits: singleColumn ? 1 ... 1 : 1 ... 3
        )
    }

    private func proyekGridView(columns: [GridItem], sidePadding: CGFloat) -> some View {
        LazyVGrid(columns: columns, spacing: 20) {
            ForEach(displayedProyek) { item in
                proyekCardCell(for: item)
            }
        }
        .padding(.horizontal, sidePadding)
        .padding(.bottom, 24)
    }

    @ViewBuilder
    private func proyekCardCell(for item: Proyek) -> some View {
        let detailVM = getOrMakeViewModel(for: item)

        BakCardView(
            proyek: item,
            viewModel: detailVM,
            onMulaiPindai: {
                if item.status == .aktif {
                    reconnectProyek(proyek: item)
                } else {
                    scanSetupTarget = item
                }
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
}

extension ProyekListView {
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

        if activeAlertTarget == nil, repairTarget == nil {
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
        store.viewModel(for: proyek, service: serviceProvider(proyek))
    }

    private func resumeAlreadyScannedProjects() {
        for proyek in displayedProyek where proyek.status == .aktif {
            let detailViewModel = getOrMakeViewModel(for: proyek)
            if detailViewModel.isDataScanned {
                detailViewModel.lanjutkanPengukuran()
            }
        }
    }

    private func startScanAfterSetup(for proyek: Proyek) {
        print("[List] 🚀 startScanAfterSetup \(proyek.nama)")
        queuedAlertTargets.removeAll { $0.id == proyek.id }
        store.remove(proyek.id)

        let detailViewModel = getOrMakeViewModel(for: proyek)
        Task {
            await detailViewModel.mulaiPindaiDenganBaselineAwal(in: modelContext)
        }
    }

    /// Reconnects an active bak whose IoT sensor disconnected, retrieving and preserving its saved `Proyek` data.
    private func reconnectProyek(proyek: Proyek) {
        print("[List] 🔄 reconnectProyek \(proyek.nama)")
        guard proyek.perangkatID != nil else {
            deviceSwitchTarget = proyek
            return
        }

        store.remove(proyek.id)
        let detailViewModel = getOrMakeViewModel(for: proyek)
        Task {
            await detailViewModel.sambungkanUlang(in: modelContext)
        }
    }

    private func switchDeviceAndReconnect(for proyek: Proyek, to device: DiscoveredDevice) {
        proyek.perangkatNama = device.nama
        proyek.perangkatID = device.id
        try? modelContext.save()
        reconnectProyek(proyek: proyek)
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
            proyek.selesaikan()
            try? modelContext.save()
        }
        store.remove(proyek.id)
    }

    // MARK: - Alert Bindings

    private var activeScanError: (proyek: Proyek?, message: String)? {
        guard let vm = store.allViewModels.first(where: { $0.colorMeasurementError != nil }),
              let message = vm.colorMeasurementError
        else { return nil }
        return (vm.proyek, message)
    }

    private var scanErrorIsPresented: Binding<Bool> {
        Binding(
            get: { activeScanError != nil },
            set: { isPresented in
                if !isPresented {
                    clearAllScanErrors()
                }
            }
        )
    }

    private func clearAllScanErrors() {
        for detailViewModel in store.allViewModels {
            detailViewModel.clearColorMeasurementError()
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
