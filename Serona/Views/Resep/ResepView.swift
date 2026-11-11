//
//  ResepView.swift
//  Serona
//

import SwiftData
import SwiftUI

struct ResepView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Resep.dibuat, order: .reverse) private var daftar: [Resep]
    @State private var showModal = false
    @State private var teksCari = ""
    @ScaledMetric(relativeTo: .largeTitle) private var ukuranIkon = 100.0

    private var hasilCari: [Resep] {
        daftar.cari(teksCari)
    }
    
    private let backgroundColor = Color("backgroundColor")
    private let titleColor = Color("titleColor")

    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 20) {
                Text("Warna")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(titleColor)
                    .padding(.horizontal, 24)
                content
            }
        }
            .background(backgroundColor.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
//            .searchable(text: $teksCari, placement: .navigationBarDrawer(displayMode: .always), prompt: "Cari Warna")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showModal = true
                    } label: {
                        Label("Tambah Warna", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .sheet(isPresented: $showModal) {
                NavigationStack {
                    HalamanTambahResep()
                }
            }
            .navigationDestination(for: Resep.self) { resep in
                HalamanTambahResep(resep: resep)
            }
    }

    @ViewBuilder
    private var content: some View {
        if daftar.isEmpty {
            emptyState
        } else if hasilCari.isEmpty {
            ContentUnavailableView.search(text: teksCari)
        } else {
            daftarWarna
        }
    }

    private var daftarWarna: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 235), spacing: 30)],
                spacing: 20
            ) {
                ForEach(hasilCari) { resep in
                    NavigationLink(value: resep) {
                        ResepRowView(resep: resep)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "book")
                .resizable()
                .scaledToFit()
                .frame(width: ukuranIkon, height: ukuranIkon)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text("Belum ada warna")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text("Tekan + untuk menambah warna")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Kosong") {
    NavigationStack {
        ResepView()
    }
    .modelContainer(for: SeronaSchema.models, inMemory: true)
}

#Preview("Berisi") {
    NavigationStack {
        ResepView()
    }
    .modelContainer(previewContainer)
}

#Preview("Accessibility 5") {
    NavigationStack {
        ResepView()
    }
    .modelContainer(previewContainer)
    .dynamicTypeSize(.accessibility5)
}

#Preview("Kosong Accessibility 5") {
    NavigationStack {
        ResepView()
    }
    .modelContainer(for: SeronaSchema.models, inMemory: true)
    .dynamicTypeSize(.accessibility5)
}

@MainActor
private let previewContainer: ModelContainer = {
    // swiftlint:disable:next force_try
    let container = try! SeronaSchema.makeContainer(inMemory: true)
    container.mainContext.insert(Resep(
        namaWarna: "Merah Marun", warnaHex: "#B50202",
        air: 1000, kepekatan: 80, batasPH: 7
    ))
    container.mainContext.insert(Resep(
        namaWarna: "Biru Laut", warnaHex: "#0044AA",
        air: 1000, kepekatan: 80, batasPH: 7
    ))
    container.mainContext.insert(Resep(
        namaWarna: "Biru 2", warnaHex: "#0043AA",
        air: 1000, kepekatan: 80, batasPH: 7
    ))
    container.mainContext.insert(Resep(
        namaWarna: "Biru 3", warnaHex: "#0046AA",
        air: 1000, kepekatan: 80, batasPH: 7
    ))
    container.mainContext.insert(Resep(
        namaWarna: "Biru 3", warnaHex: "#0046AA",
        air: 1000, kepekatan: 80, batasPH: 7
    ))
    return container
}()
