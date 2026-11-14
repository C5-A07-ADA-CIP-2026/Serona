//
//  ResepView.swift
//  Serona
//

import SwiftData
import SwiftUI

struct ResepView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Resep.dibuat, order: .reverse) private var daftar: [Resep]

    @State private var teksCari = ""

    private var hasilCari: [Resep] {
        daftar.cari(teksCari)
    }
    @State private var resepDipilih: Resep?

    private let backgroundColor = Color("backgroundColor")
    private let titleColor = Color("titleColor")
    private let oliveGreen = Color("oliveGreen")

    var body: some View {
        ZStack {
            BackgroundGradient()
            
            GeometryReader { geometry in
                let isLandscape = geometry.size.width > geometry.size.height
                let columnsCount = isLandscape ? 5 : 3
                let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 16), count: columnsCount)

                VStack(alignment: .leading, spacing: 20) {
                    Text("Resep Warna")
                        .font(.largeTitle.bold())
                        .foregroundStyle(titleColor)
                        .padding(.horizontal, 24)
                        .padding(.top, 12)

                    ScrollView {
                        if daftar.isEmpty {
                            emptyState
                        } else if hasilCari.isEmpty {
                            ContentUnavailableView.search(text: teksCari)
                                .padding(.top, 40)
                        } else {
                            LazyVGrid(columns: gridColumns, spacing: 16) {
                                ForEach(hasilCari) { resep in
                                    Button {
                                        resepDipilih = resep
                                    } label: {
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
        .sheet(item: $resepDipilih) { resep in
            HalamanTambahResep(resep: resep, tampilSebagaiSheet: true)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "Belum ada warna",
            systemImage: "book",
            description: Text("Tekan + untuk menambah warna.")
        )
        .padding(.top, 40)
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
    let container = try! SeronaSchema.makeContainer(inMemory: true)
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
