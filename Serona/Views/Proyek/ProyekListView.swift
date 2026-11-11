//
//  ProyekListView.swift
//  Serona
//


import SwiftData
import SwiftUI

enum HeaderTab: String, CaseIterable {
    case proyek = "Bak"
    case resep = "Warna"
}

// Wrapper to identify which project repair guide sheet is being presented
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
    @State private var isShowingTambah = false
    @State private var selectedTab: HeaderTab = .proyek
    @State private var searchText: String = ""
    @State private var isSearching: Bool = false

    // Maintains active view models so scanning continues and updates live
    @State private var activeViewModels: [UUID: ProyekDetailViewModel] = [:]
    // Tracks which project repair guide is currently presented
    @State private var repairTarget: ProyekRepairTarget?

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

    private let backgroundColor = Color(red: 0.98, green: 0.97, blue: 0.93)
    private let titleColor = Color(red: 0.38, green: 0.15, blue: 0.15)
    private let oliveGreen = Color(red: 0.35, green: 0.42, blue: 0.25)

    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()

            if selectedTab == .resep {
                ResepView(selectedTab: $selectedTab)
            } else {
                GeometryReader { geometry in
                    let isLandscape = geometry.size.width > geometry.size.height
                    let columnsCount = isLandscape ? 3 : 2
                    let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 20), count: columnsCount)

                    VStack(alignment: .leading, spacing: 16) {
                        topHeaderBar

                        if isSearching {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(titleColor.opacity(0.6))

                                TextField("Cari Bak / Proyek…", text: $searchText)
                                    .autocorrectionDisabled()

                                if !searchText.isEmpty {
                                    Button {
                                        searchText = ""
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.gray)
                                    }
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal, 24)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        Text("Bak")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(titleColor)
                            .padding(.horizontal, 24)

                        ScrollView {
                            if activeProyek.isEmpty {
                                ContentUnavailableView(
                                    searchText.isEmpty ? "Belum ada proyek aktif" : "Proyek tidak ditemukan",
                                    systemImage: "folder",
                                    description: Text(searchText.isEmpty ? "Tekan + untuk menambah proyek." : "Coba kata kunci pencarian lain.")
                                )
                                .padding(.top, 40)
                            } else {
                                LazyVGrid(columns: gridColumns, spacing: 20) {
                                    ForEach(activeProyek) { item in
                                        let detailVM = getOrMakeViewModel(for: item)
                                        let hasAlert = detailVM.qualityAlert != nil || detailVM.currentIssue != nil || item.nama.contains("Merah Ungu")

                                        if hasAlert {
                                            // Clickable ONLY when warning is active -> opens repair guide
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
                                            // Static / Non-clickable in normal state
                                            BakCardView(proyek: item, viewModel: detailVM)
                                        }
                                    }
                                }
                                .padding(.horizontal, 24)
                                .padding(.bottom, 24)
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingTambah) {
            TambahProyekView { createdProyek in
                // Automatically start scanning when checkmark button is clicked
                startScan(for: createdProyek)
            }
        }
        .sheet(item: $repairTarget) { target in
            // Perbaiki Larutan guide sheet presented when tapping card with warning
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

    // MARK: - Scanning & ViewModel Management

    private func getOrMakeViewModel(for proyek: Proyek) -> ProyekDetailViewModel {
        if let existing = activeViewModels[proyek.id] {
            return existing
        }
        let vm = ProyekDetailViewModel(proyek: proyek)
        activeViewModels[proyek.id] = vm
        return vm
    }

    private func startScan(for proyek: Proyek) {
        let vm = getOrMakeViewModel(for: proyek)
        Task {
            await vm.mulaiPindai()
        }
    }

    // MARK: - Header Bar

    private var topHeaderBar: some View {
        HStack {
            Spacer()

            HStack(spacing: 4) {
                ForEach(HeaderTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = tab
                        }
                    } label: {
                        Text(tab.rawValue)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(selectedTab == tab ? oliveGreen : titleColor.opacity(0.8))
                            .frame(width: 130, height: 36)
                            .background {
                                if selectedTab == tab {
                                    RoundedRectangle(cornerRadius: 18)
                                        .fill(Color.white)
                                        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
                                }
                            }
                    }
                }

                Button {
                    withAnimation {
                        isSearching.toggle()
                        if !isSearching {
                            searchText = ""
                        }
                    }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isSearching ? oliveGreen : titleColor.opacity(0.8))
                        .frame(width: 36, height: 36)
                }
                .padding(.trailing, 4)
            }
            .padding(4)
            .background(Color(red: 0.94, green: 0.93, blue: 0.88))
            .clipShape(Capsule())

            Spacer()

            Button {
                isShowingTambah = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(oliveGreen)
                    .clipShape(Circle())
                    .shadow(color: oliveGreen.opacity(0.3), radius: 4, x: 0, y: 2)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
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

    // Active Projects
    context.insert(Proyek(nama: "Bak Merah Ungu", perangkatNama: "ESP 32", resep: resepUngu, jumlahKain: 2, tanggal: .now))
    context.insert(Proyek(nama: "Bak Merah Ungu", perangkatNama: "ESP 32", resep: resepUngu, jumlahKain: 2, tanggal: .now.addingTimeInterval(-60)))
    context.insert(Proyek(nama: "Bak Marun", perangkatNama: "ESP 32", resep: resepMarun, jumlahKain: 1, tanggal: .now.addingTimeInterval(-180)))

    // Finished (Nonaktif) Projects
    let selesaiProyek = Proyek(nama: "Bak Merah Bata", perangkatNama: "ESP 32", resep: resepUngu, jumlahKain: 3, tanggal: .now.addingTimeInterval(-300))
    selesaiProyek.selesaikan(kepekatanAkhir: 94, phAkhir: 9)
    context.insert(selesaiProyek)

    return container
}()
