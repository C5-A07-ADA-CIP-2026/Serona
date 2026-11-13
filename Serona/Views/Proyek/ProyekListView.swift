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

struct ProyekListView: View {
    @Query(sort: \Proyek.tanggal, order: .reverse) private var semuaProyek: [Proyek]
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ProyekListViewModel()
    @State private var searchText: String = ""

    @State private var activeViewModels: [UUID: ProyekDetailViewModel] = [:]
    @State private var repairTarget: ProyekRepairTarget?

    private let backgroundColor = Color("backgroundColor")
    private let titleColor = Color("titleColor")
    private let oliveGreen = Color("oliveGreen")

    private var daftar: ProyekDaftar {
        ProyekDaftar(semuaProyek)
    }

    private var activeProyek: [Proyek] {
        let activeList = daftar.aktif
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return activeList
        }
        return activeList.filter { $0.nama.localizedCaseInsensitiveContains(searchText) }
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
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(titleColor)
                        .padding(.horizontal, 24)
                        .padding(.top, 12)

                    ScrollView {
                        if activeProyek.isEmpty {
                            emptyStateView
                        } else {
                            proyekGridView(columns: gridColumns)
                        }
                    }
                }
            }
        }
        .onAppear {
            startScansForActiveProjects()
        }
        .onChange(of: activeProyek.map(\.id)) { _, _ in
            startScansForActiveProjects()
        }
        .sheet(item: $repairTarget) { target in
            PerbaikiLarutanView(issue: target.issue, viewModel: target.viewModel)
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

    private var emptyStateView: some View {
        ContentUnavailableView(
            searchText.isEmpty ? "Belum ada proyek aktif" : "Proyek tidak ditemukan",
            systemImage: "folder",
            description: Text(searchText.isEmpty ? "Tekan + untuk menambah proyek." : "Coba kata kunci pencarian lain.")
        )
        .padding(.top, 40)
    }

    private func proyekGridView(columns: [GridItem]) -> some View {
        LazyVGrid(columns: columns, spacing: 20) {
            ForEach(activeProyek) { item in
                proyekCardCell(for: item)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    @ViewBuilder
    private func proyekCardCell(for item: Proyek) -> some View {
        let detailVM = getOrMakeViewModel(for: item)
        let hasAlert = detailVM.qualityAlert != nil || detailVM.currentIssue != nil || item.nama.contains("Merah Ungu")

        if hasAlert {
            Button {
                let issue = detailVM.qualityAlert?.issue ?? detailVM.currentIssue ?? .keduanya
                repairTarget = ProyekRepairTarget(
                    id: item.id,
                    proyek: item,
                    viewModel: detailVM,
                    issue: issue
                )
            } label: {
                BakCardView(proyek: item, viewModel: detailVM)
            }
            .buttonStyle(.plain)
        } else {
            BakCardView(proyek: item, viewModel: detailVM)
        }
    }

    // MARK: - Scanning & ViewModel Management

    private func getOrMakeViewModel(for proyek: Proyek) -> ProyekDetailViewModel {
        if let existing = activeViewModels[proyek.id] {
            return existing
        }
        let vm = ProyekDetailViewModel(proyek: proyek)
        activeViewModels[proyek.id] = vm
        return vm
    }

    private func startScansForActiveProjects() {
        for proyek in activeProyek where activeViewModels[proyek.id] == nil {
            let vm = getOrMakeViewModel(for: proyek)
            Task {
                await vm.mulaiPindai()
            }
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

#Preview("iPad Landscape (3 Columns x 2 Rows)", traits: .landscapeLeft) {
    NavigationStack {
        ProyekListView()
    }
    .modelContainer(previewGridContainer)
}

#Preview("iPad Portrait (2 Columns x 3 Rows)", traits: .portrait) {
    NavigationStack {
        ProyekListView()
    }
    .modelContainer(previewGridContainer)
}

#Preview("Kosong", traits: .landscapeLeft) {
    NavigationStack {
        ProyekListView()
    }
    .modelContainer(for: SeronaSchema.models, inMemory: true)
}

// MARK: - Sample Data Container

@MainActor
private let previewGridContainer: ModelContainer = {
    let container = try! SeronaSchema.makeContainer(inMemory: true)
    let context = container.mainContext

    let resepUngu = Resep(
        namaWarna: "Merah Ungu", warnaHex: "#B50202",
        air: 1000, kepekatan: 80, batasPH: 7
    )
    let resepMarun = Resep(
        namaWarna: "Marun", warnaHex: "#800000",
        air: 1000, kepekatan: 80, batasPH: 7
    )

    context.insert(Proyek(nama: "Bak Merah Ungu", perangkatNama: "ESP 32", resep: resepUngu, jumlahKain: 2, tanggal: .now))
    context.insert(Proyek(nama: "Bak Merah Ungu", perangkatNama: "ESP 32", resep: resepUngu, jumlahKain: 2, tanggal: .now.addingTimeInterval(-60)))
    context.insert(Proyek(nama: "Bak Marun", perangkatNama: "ESP 32", resep: resepMarun, jumlahKain: 1, tanggal: .now.addingTimeInterval(-180)))

    let selesaiProyek = Proyek(nama: "Bak Merah Bata", perangkatNama: "ESP 32", resep: resepUngu, jumlahKain: 3, tanggal: .now.addingTimeInterval(-300))
    selesaiProyek.selesaikan(kepekatanAkhir: 94, phAkhir: 9)
    context.insert(selesaiProyek)

    return container
}()
