//
//  ResepView.swift
//  Serona
//

import SwiftData
import SwiftUI

struct ResepView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Resep.dibuat, order: .reverse) private var daftar: [Resep]

    @Binding var teksCari: String
    @State private var resepDipilih: Resep?

    init(teksCari: Binding<String> = .constant("")) {
        _teksCari = teksCari
    }

    private var hasilCari: [Resep] {
        daftar.cari(teksCari)
    }

    private let backgroundColor = Color("backgroundColor")
    private let titleColor = Color("titleColor")
    private let oliveGreen = Color("oliveGreen")

    var body: some View {
        ZStack {
            BackgroundGradient()

            GeometryReader { geometry in
                let gridColumns = AdaptiveLayout.gridColumns(
                    forWidth: geometry.size.width, minimumItemWidth: 250, spacing: 40,
                    limits: dynamicTypeSize.isAccessibilitySize ? 1 ... 1 : 2 ... 5
                )
                let sidePadding = AdaptiveLayout.sidePadding(forWidth: geometry.size.width)

                VStack(alignment: .leading, spacing: 20) {
                    Text("Resep Warna")
                        .font(.largeTitle.bold())
                        .foregroundStyle(titleColor)
                        .padding(.horizontal, sidePadding)
                        .padding(.top, 12)

                    if daftar.isEmpty {
                        emptyState
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if hasilCari.isEmpty {
                        ContentUnavailableView.search(text: teksCari)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVGrid(columns: gridColumns, spacing: 50) {
                                ForEach(hasilCari) { resep in
                                    Button {
                                        resepDipilih = resep
                                    } label: {
                                        WarnaCardView(resep: resep)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, sidePadding)
                            .padding(.bottom, 24)
                        }
                    }
                }
            }
        }
        .sheet(item: $resepDipilih) { resep in
            HalamanTambahResep(resep: resep, tampilSebagaiSheet: true)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image("IconResepWarna")
                .resizable()
                .scaledToFit()
                .frame(width: 110, height: 110)
                .accessibilityHidden(true)

            VStack(spacing: 4) {
                Text("Tidak Ada Resep Warna")
                    .font(.title3.bold())
                    .foregroundStyle(Color(hex: "#B89B8D"))

                Text("Tekan tanda + untuk menambahkan resep")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color(hex: "#B89B8D"))
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
        .padding(.bottom, 48)
    }
}

// MARK: - Previews

#Preview("ResepView", traits: .landscapeLeft) {
    NavigationStack {
        ResepView()
    }
    .modelContainer(previewResepContainer(isi: true))
}

#Preview("Empty State", traits: .landscapeLeft) {
    NavigationStack {
        ResepView()
    }
    .modelContainer(previewResepContainer(isi: false))
}

// MARK: - Preview Data Container

@MainActor
private func previewResepContainer(isi: Bool) -> ModelContainer {
    let container = SeronaSchema.makePreviewContainer()
    guard isi else { return container }
    let context = container.mainContext

    context.insert(Resep(namaWarna: "Cokelat Bata", warnaHex: "#C0533E", air: 1000, kepekatan: 80, batasPH: 7))
    context.insert(Resep(namaWarna: "Ungu Muda", warnaHex: "#B85282", air: 1000, kepekatan: 80, batasPH: 7))
    context.insert(Resep(namaWarna: "Ungu Tua", warnaHex: "#9B3B6B", air: 1000, kepekatan: 80, batasPH: 7))
    context.insert(Resep(namaWarna: "Merah Bata", warnaHex: "#B23B4E", air: 1000, kepekatan: 80, batasPH: 7))
    context.insert(Resep(namaWarna: "Marun", warnaHex: "#800000", air: 1000, kepekatan: 80, batasPH: 7))
    context.insert(Resep(namaWarna: "Merah Anggur", warnaHex: "#8B2B43", air: 1000, kepekatan: 80, batasPH: 7))
    context.insert(Resep(namaWarna: "Ungu Abu", warnaHex: "#6B4F69", air: 1000, kepekatan: 80, batasPH: 7))
    context.insert(Resep(namaWarna: "Krem", warnaHex: "#F29F75", air: 1000, kepekatan: 80, batasPH: 7))
    context.insert(Resep(namaWarna: "Merah Ungu", warnaHex: "#B50202", air: 1000, kepekatan: 80, batasPH: 7))

    return container
}
