//
//  ContentView.swift
//  Serona
//
//  Created by Hana Azizah Nurhadi on 21/10/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    
    enum HeaderTab: String, CaseIterable {
        case proyek = "Bak Warna"
        case resep = "Resep Warna"
    }
    
    @State private var selectedTab: HeaderTab = .proyek
//    @State private var isSearching = false
    @State private var isShowingTambah = false
    
    private let oliveGreen = Color("oliveGreen")
    private let titleColor = Color("titleColor")
    
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
        .sheet(isPresented: $isShowingTambah) {
            switch selectedTab {
            case .proyek:
                TambahProyekView()
            case .resep:
                HalamanTambahResep(tampilSebagaiSheet: true)
            }
        }
    }
    
    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .proyek:
            ProyekListView()
        case .resep:
            ResepView()
        }
    }
    
    private var topHeaderBar: some View {
        HStack {
            Spacer()
            segmentedPill
            Spacer()
//            addButton
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }

    private var segmentedPill: some View {
        HStack(spacing: 4) {
            ForEach(HeaderTab.allCases, id: \.self) { tab in
                tabButton(for: tab)
            }
//            searchButton
        }
        .padding(4)
        .background(pillBackground)
        .clipShape(Capsule())
    }

    private func tabButton(for tab: HeaderTab) -> some View {
        let isSelected = selectedTab == tab
        let textColor: Color = isSelected ? oliveGreen : titleColor.opacity(0.8)

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = tab
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
    }

//    private var searchButton: some View {
//        Button {
//            isSearching.toggle()
//        } label: {
//            Image(systemName: "magnifyingglass")
//                .font(.system(size: 16, weight: .semibold))
//                .foregroundStyle(titleColor.opacity(0.8))
//                .frame(width: 36, height: 36)
//        }
//        .padding(.trailing, 4)
//    }

//    private var addButton: some View {
//        Button {
//            isShowingTambah = true
//        } label: {
//            Image(systemName: "plus")
//                .font(.title3.bold())
//                .foregroundStyle(.white)
//                .frame(width: 44, height: 44)
//                .background(oliveGreen)
//                .clipShape(Circle())
//                .shadow(color: oliveGreen.opacity(0.3), radius: 4, x: 0, y: 2)
//        }
//    }

    private var pillBackground: Color {
        Color(red: 0.94, green: 0.93, blue: 0.88)
    }
}

#Preview(traits: .landscapeLeft) {
    ContentView()
        .modelContainer(for: SeronaSchema.models, inMemory: true)
}
