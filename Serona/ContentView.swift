//
//  ContentView.swift
//  Serona
//
//  Created by Hana Azizah Nurhadi on 21/10/26.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    enum HeaderTab: String, CaseIterable {
        case proyek = "Bak Warna"
        case resep = "Resep Warna"
    }

    @Query(sort: \Proyek.tanggal, order: .forward) private var semuaProyek: [Proyek]

    @State private var selectedTab: HeaderTab = .proyek
    @State private var isSearching = false
    @State private var teksCari = ""
    @State private var isShowingTambahProyek = false
    @State private var isShowingTambahResep = false
    @State private var newlyCreatedProyek: Proyek?
    @FocusState private var isSearchFieldFocused: Bool

    private let oliveGreen = Color("oliveGreen")
    private let titleColor = Color("titleColor")
    private let maxBakCount = 6

    private var canAddBak: Bool {
        semuaProyek.count < maxBakCount
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                topHeaderBar

                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(BackgroundGradient())
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $isShowingTambahProyek) {
            TambahProyekView(
                deviceService: DeviceConnectionServices.default
            ) { newProyek in
                newlyCreatedProyek = newProyek
            }
        }
        .sheet(isPresented: $isShowingTambahResep) {
            HalamanTambahResep(tampilSebagaiSheet: true)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .proyek:
            ProyekListView(
                newlyCreatedProyek: $newlyCreatedProyek,
                serviceProvider: { proyek in
                    proyek.perangkatID.map { DeviceConnectionServices.default.measurementSource(for: $0) }
                },
                deviceConnectingProvider: { DeviceConnectionServices.default }
            )
        case .resep:
            ResepView(teksCari: $teksCari)
        }
    }

    private var topHeaderBar: some View {
        ZStack {
            segmentedPill

            HStack(spacing: 10) {
                Spacer()

                if selectedTab == .resep {
                    searchControl
                }

                addButton
            }
        }
        .padding(.horizontal)
        .padding(.top)
    }

    private var segmentedPill: some View {
        HStack(spacing: 4) {
            ForEach(HeaderTab.allCases, id: \.self) { tab in
                tabButton(for: tab)
            }
        }
        .padding(4)
        .background(pillBackground, in: Capsule())
    }

    private func tabButton(for tab: HeaderTab) -> some View {
        let isSelected = selectedTab == tab
        let textColor: Color = isSelected ? oliveGreen : titleColor.opacity(0.8)

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = tab
                if tab != .resep {
                    isSearching = false
                    teksCari = ""
                    isSearchFieldFocused = false
                }
            }
        } label: {
            Text(tab.rawValue)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(textColor)
                .frame(width: 130, height: 36)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(.clear)
                            .glassEffect(
                                .regular,
                                in: RoundedRectangle(cornerRadius: 18)
                            )
                    }
                }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var searchControl: some View {
        if isSearching {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(titleColor.opacity(0.75))

                TextField("Cari warna...", text: $teksCari)
                    .font(.subheadline)
                    .autocorrectionDisabled()
                    .focused($isSearchFieldFocused)

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        teksCari = ""
                        isSearching = false
                        isSearchFieldFocused = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.bold())
                        .foregroundStyle(titleColor.opacity(0.75))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Tutup pencarian")
            }
            .padding(.horizontal, 14)
            .frame(width: 240, height: 44)
            .glassEffect(.regular, in: Capsule())
            .transition(.scale(scale: 0.9, anchor: .trailing).combined(with: .opacity))
        } else {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isSearching = true
                    isSearchFieldFocused = true
                }
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.title2)
                    .foregroundStyle(.black)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
            .controlSize(.large)
            .tint(searchButtonBackground)
            .glassEffect(.regular, in: Circle())
            .accessibilityLabel("Cari Warna")
            .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
    }

    private var addButton: some View {
        let isDisabled = (selectedTab == .proyek && !canAddBak)

        return Button(
            selectedTab == .proyek ? "Tambah Bak" : "Tambah Warna",
            systemImage: "plus"
        ) {
            if selectedTab == .proyek {
                isShowingTambahProyek = true
            } else {
                isShowingTambahResep = true
            }
        }
        .labelStyle(.iconOnly)
        .font(.title3.bold())
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.circle)
        .controlSize(.large)
        .tint(oliveGreen)
        .shadow(color: oliveGreen.opacity(isDisabled ? 0 : 0.3), radius: 4, x: 0, y: 2)
        .disabled(isDisabled)
    }

    private var pillBackground: Color {
        Color(red: 0.94, green: 0.93, blue: 0.88)
    }

    private var searchButtonBackground: Color {
        Color(red: 0.96, green: 0.95, blue: 0.91)
    }
}

#Preview(traits: .landscapeLeft) {
    ContentView()
        .modelContainer(for: SeronaSchema.models, inMemory: true)
}
