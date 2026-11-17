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

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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

    private var isCompactWidth: Bool {
        horizontalSizeClass == .compact
    }

    /// Tabs fill the row on a phone and at accessibility text sizes, where their labels need the room.
    private var tabsFillWidth: Bool {
        isCompactWidth || dynamicTypeSize.isAccessibilitySize
    }

    @ViewBuilder
    private var topHeaderBar: some View {
        if isCompactWidth || dynamicTypeSize.isAccessibilitySize {
            compactHeaderBar
        } else {
            regularHeaderBar
        }
    }

    /// iPad: the tabs stay centered while the actions sit at the trailing edge.
    private var regularHeaderBar: some View {
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

    /// iPhone: the tabs share the row with the actions, so they must give way. While searching, the field takes
    /// the room of the tabs. When the text is too large for one row (Dynamic Type), the actions move below the tabs.
    private var compactHeaderBar: some View {
        ViewThatFits(in: .horizontal) {
            compactSingleRow
            compactStackedRows
        }
        .padding(.horizontal)
        .padding(.top)
    }

    private var compactSingleRow: some View {
        HStack(spacing: 10) {
            if isSearching, selectedTab == .resep {
                searchControl
            } else {
                segmentedPill

                if selectedTab == .resep {
                    searchControl
                }
            }

            addButton
        }
    }

    private var compactStackedRows: some View {
        VStack(alignment: .trailing, spacing: 10) {
            if !(isSearching && selectedTab == .resep) {
                segmentedPill
            }

            HStack(spacing: 10) {
                if selectedTab == .resep {
                    searchControl
                }

                addButton
            }
        }
    }

    private var segmentedPill: some View {
        // At accessibility text sizes the tabs stack, so neither label is cut off.
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 4))
            : AnyLayout(HStackLayout(spacing: 4))

        return layout {
            ForEach(HeaderTab.allCases, id: \.self) { tab in
                tabButton(for: tab)
            }
        }
        .padding(4)
        .background(pillBackground, in: Capsule())
        .frame(maxWidth: tabsFillWidth ? .infinity : nil)
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
                .multilineTextAlignment(.center)
                .foregroundStyle(textColor)
                .frame(maxWidth: tabsFillWidth ? .infinity : 160, minHeight: 44)
                .padding(.horizontal, 8)
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
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Tutup pencarian")
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: isCompactWidth ? .infinity : 240, minHeight: 44)
            .frame(width: isCompactWidth ? nil : 240)
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
