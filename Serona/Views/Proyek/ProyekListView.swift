//
//  ProyekListView.swift
//  Serona
//

import SwiftData
import SwiftUI

/// The Proyek tab: active projects first, then inactive (finished) ones.
struct ProyekListView: View {
    @Query(sort: \Proyek.tanggal, order: .reverse) private var semuaProyek: [Proyek]
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ProyekListViewModel()
    @State private var isShowingTambah = false
    @State private var selectedTab: HeaderTab = .proyek
    @State private var searchText: String = ""
    @State private var isSearching: Bool = false
    
    enum HeaderTab: String, CaseIterable {
        case proyek = "Bak"
        case resep = "Resep"
    }
    
    private var daftar: ProyekDaftar {
        ProyekDaftar(semuaProyek)
    }
    
    // Colors matching
    private let backgroundColor = Color(red: 0.98, green: 0.97, blue: 0.93)
    private let titleColor = Color(red: 0.38, green: 0.15, blue: 0.15)
    private let oliveGreen = Color(red: 0.35, green: 0.42, blue: 0.25)
    
    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()
            
            GeometryReader { geometry in
                let isLandscape = geometry.size.width > geometry.size.height
                let columnsCount = isLandscape ? 3 : 2
                let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 20), count: columnsCount)
                
                VStack(alignment: .leading, spacing: 20) {
                    // Top Custom Header
                    topHeaderBar
                    
                    // Section Title
                    Text("Bak")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(titleColor)
                        .padding(.horizontal, 24)
                    
                    ScrollView {
                        if daftar.isEmpty {
                            ContentUnavailableView(
                                "Belum ada proyek",
                                systemImage: "folder",
                                description: Text("Tekan + untuk menambah proyek.")
                            )
                            .padding(.top, 40)
                        } else {
                            LazyVGrid(columns: gridColumns, spacing: 20) {
                                ForEach(semuaProyek) { item in
                                    NavigationLink {
                                        ProyekDetailView(proyek: item)
                                    } label: {
                                        BakCardView(proyek: item)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.bottom, 24)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingTambah) {
            TambahProyekView()
        }
        .alert(
            "Hapus Proyek?",
            isPresented: isPresented(viewModel.proyekAkanDihapus, clear: viewModel.batalHapus),
            presenting: viewModel.proyekAkanDihapus
        ) { proyek in
            Button("Batal", role: .cancel) {}
            Button("Hapus", role: .destructive) {
                viewModel.hapus(proyek, in: modelContext)
            }
        } message: { proyek in
            Text("\(proyek.nama) akan dihapus dan tidak bisa dikembalikan.")
        }
        .alert(
            "Gagal menghapus proyek",
            isPresented: isPresented(viewModel.deleteError, clear: viewModel.clearDeleteError),
            presenting: viewModel.deleteError
        ) { _ in
            Button("Tutup", role: .cancel) {}
        } message: { error in
            Text(error)
        }
    }
    
    // MARK: - Header Bar Component
    private var topHeaderBar: some View {
        HStack {
            Spacer()
            
            // Center Segmented Control Pill
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
                
                // Search Icon Button
                Button {
                    isSearching.toggle()
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(titleColor.opacity(0.8))
                        .frame(width: 36, height: 36)
                }
                .padding(.trailing, 4)
            }
            .padding(4)
            .background(Color(red: 0.94, green: 0.93, blue: 0.88))
            .clipShape(Capsule())
            
            Spacer()
            
            // Top Right Add ("+") Button
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

#Preview("Kosong") {
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
    let resepBata = Resep(
        namaWarna: "Merah Bata", warnaHex: "#A52A2A",
        air: 1000, kepekatan: 80, batasPH: 7
    )
    
    // 6 cards to demonstrate the grid layout (3x2 in Landscape, 2x3 in Portrait)
    context.insert(Proyek(nama: "Bak Merah Ungu", perangkatNama: "ESP 32", resep: resepUngu, jumlahKain: 2, tanggal: .now))
    context.insert(Proyek(nama: "Bak Merah Ungu", perangkatNama: "ESP 32", resep: resepUngu, jumlahKain: 2, tanggal: .now.addingTimeInterval(-60)))
    context.insert(Proyek(nama: "Bak Merah Ungu", perangkatNama: "ESP 32", resep: resepUngu, jumlahKain: 2, tanggal: .now.addingTimeInterval(-120)))
    context.insert(Proyek(nama: "Bak Marun", perangkatNama: "ESP 32", resep: resepMarun, jumlahKain: 1, tanggal: .now.addingTimeInterval(-180)))
    context.insert(Proyek(nama: "Bak Merah Ungu", perangkatNama: "ESP 32", resep: resepUngu, jumlahKain: 2, tanggal: .now.addingTimeInterval(-240)))
    context.insert(Proyek(nama: "Bak Merah Bata", perangkatNama: "ESP 32", resep: resepBata, jumlahKain: 3, tanggal: .now.addingTimeInterval(-300)))
    
    return container
}()
