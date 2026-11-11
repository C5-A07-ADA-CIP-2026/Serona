//
//  ResepView.swift
//  Serona
//

import SwiftData
import SwiftUI

struct ResepView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Resep.dibuat, order: .reverse) private var daftar: [Resep]
    
    // Binding to parent tab state with default fallthrough
    @Binding var selectedTab: HeaderTab
    
    @State private var showModal = false
    @State private var teksCari = ""
    @State private var isSearching = false

    // Default initializer enables ResepView() to be instantiated without arguments
    init(selectedTab: Binding<HeaderTab> = .constant(.resep)) {
        self._selectedTab = selectedTab
    }

    private var hasilCari: [Resep] {
        daftar.cari(teksCari)
    }
    
    private let backgroundColor = Color("backgroundColor")
    private let titleColor = Color("titleColor")

    private let backgroundColor = Color(red: 0.98, green: 0.97, blue: 0.93)
    private let titleColor = Color(red: 0.38, green: 0.15, blue: 0.15)
    private let oliveGreen = Color(red: 0.35, green: 0.42, blue: 0.25)

    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()
            
//             VStack(alignment: .leading, spacing: 20) {
//                 Text("Warna")
//                     .font(.system(size: 32, weight: .bold))
//                     .foregroundStyle(titleColor)
//                     .padding(.horizontal, 24)
//                 content
//             }
//         }
//             .background(backgroundColor.ignoresSafeArea())
//             .navigationBarTitleDisplayMode(.inline)
// //            .searchable(text: $teksCari, placement: .navigationBarDrawer(displayMode: .always), prompt: "Cari Warna")
//             .toolbar {
//                 ToolbarItem(placement: .topBarTrailing) {

            GeometryReader { geometry in
                let isLandscape = geometry.size.width > geometry.size.height
                let columnsCount = isLandscape ? 5 : 3
                let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 16), count: columnsCount)

                VStack(alignment: .leading, spacing: 16) {
                    // Top Custom Header Bar
                    topHeaderBar

                    // Search Input Bar
                    if isSearching {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(titleColor.opacity(0.6))

                            TextField("Cari Warna…", text: $teksCari)
                                .autocorrectionDisabled()

                            if !teksCari.isEmpty {
                                Button {
                                    teksCari = ""
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

                    // Section Title: "Warna"
                    Text("Warna")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(titleColor)
                        .padding(.horizontal, 24)

                    // Grid List
                    ScrollView {
                        if daftar.isEmpty {
                            emptyState
                        } else {
                            LazyVGrid(columns: gridColumns, spacing: 16) {
                                ForEach(hasilCari) { resep in
                                    NavigationLink(value: resep) {
                                        WarnaCardView(resep: resep)
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
        .sheet(isPresented: $showModal) {
            HalamanTambahResep(tampilSebagaiSheet: true)
        }
        .navigationDestination(for: Resep.self) { resep in
            HalamanTambahResep(resep: resep)
        }
    }

    // MARK: - Top Header Component
    private var topHeaderBar: some View {
        HStack {
            Spacer()

            // Segmented Control Pill connected to @Binding
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
    //         }
    //         .sheet(isPresented: $showModal) {
    //             NavigationStack {
    //                 HalamanTambahResep()
    //             }
    //         }
    //         .navigationDestination(for: Resep.self) { resep in
    //             HalamanTambahResep(resep: resep)
    //         }
    // }

    // @ViewBuilder
    // private var content: some View {
    //     if daftar.isEmpty {
    //         emptyState
    //     } else if hasilCari.isEmpty {
    //         ContentUnavailableView.search(text: teksCari)
    //     } else {
    //         daftarWarna
    //     }
    // }

    // private var daftarWarna: some View {
    //     ScrollView {
    //         LazyVGrid(
    //             columns: [GridItem(.adaptive(minimum: 235), spacing: 30)],
    //             spacing: 20
    //         ) {
    //             ForEach(hasilCari) { resep in
    //                 NavigationLink(value: resep) {
    //                     ResepRowView(resep: resep)

                // Search Icon Button
                Button {
                    withAnimation {
                        isSearching.toggle()
                        if !isSearching {
                            teksCari = ""
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

            // Plus ("+") Button
            Button {
                showModal = true
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

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "book")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundStyle(.secondary)

            Text("Belum ada warna")
                .font(.title2)
                .foregroundStyle(titleColor)

            Text("Tekan + untuk menambah warna")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }
}

// MARK: - Previews
#Preview("ResepView", traits: .landscapeLeft) {
    ResepView()
        .modelContainer(for: SeronaSchema.models, inMemory: true)
}

// MARK: - Preview Data Container

@MainActor
private let previewResepContainer: ModelContainer = {
    let container = try! SeronaSchema.makeContainer(inMemory: true)
    // container.mainContext.insert(Resep(
    //     namaWarna: "Merah Marun", warnaHex: "#B50202",
    //     air: 1000, kepekatan: 80, batasPH: 7
    // ))
    // container.mainContext.insert(Resep(
    //     namaWarna: "Biru Laut", warnaHex: "#0044AA",
    //     air: 1000, kepekatan: 80, batasPH: 7
    // ))
    // container.mainContext.insert(Resep(
    //     namaWarna: "Biru 2", warnaHex: "#0043AA",
    //     air: 1000, kepekatan: 80, batasPH: 7
    // ))
    // container.mainContext.insert(Resep(
    //     namaWarna: "Biru 3", warnaHex: "#0046AA",
    //     air: 1000, kepekatan: 80, batasPH: 7
    // ))
    // container.mainContext.insert(Resep(
    //     namaWarna: "Biru 3", warnaHex: "#0046AA",
    //     air: 1000, kepekatan: 80, batasPH: 7
    // ))
    let context = container.mainContext
    
    context.insert(Resep(namaWarna: "Cokelat Bata", warnaHex: "#C0533E", air: 1000, kepekatan: 80, batasPH: 7))
    context.insert(Resep(namaWarna: "Ungu Muda", warnaHex: "#B85282", air: 1000, kepekatan: 80, batasPH: 7))
    context.insert(Resep(namaWarna: "Ungu Tua", warnaHex: "#9B3B6B", air: 1000, kepekatan: 80, batasPH: 7))
    context.insert(Resep(namaWarna: "Merah Bata", warnaHex: "#B23B4E", air: 1000, kepekatan: 80, batasPH: 7))
    context.insert(Resep(namaWarna: "Marun", warnaHex: "#800000", air: 1000, kepekatan: 80, batasPH: 7)) // Pending scan card
    context.insert(Resep(namaWarna: "Merah Anggur", warnaHex: "#8B2B43", air: 1000, kepekatan: 80, batasPH: 7))
    context.insert(Resep(namaWarna: "Ungu Abu", warnaHex: "#6B4F69", air: 1000, kepekatan: 80, batasPH: 7))
    context.insert(Resep(namaWarna: "Krem", warnaHex: "#F29F75", air: 1000, kepekatan: 80, batasPH: 7))
    context.insert(Resep(namaWarna: "Merah Ungu", warnaHex: "#B50202", air: 1000, kepekatan: 80, batasPH: 7))
    
    return container
}()
