//
//  PilihResepSheetView.swift
//  Serona
//

import SwiftData
import SwiftUI

struct PilihResepSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Resep.dibuat, order: .reverse) private var daftar: [Resep]
    @State private var teksCari: String = ""

    let onSelect: (Resep) -> Void

    private let titleColor = Color(red: 0.38, green: 0.15, blue: 0.15)
    private let sheetBg = Color(red: 0.98, green: 0.97, blue: 0.93)

    private var hasilCari: [Resep] {
        daftar.cari(teksCari)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Modal Header Bar (Title center, X right)
            modalHeaderBar
                .padding(.horizontal, 20)
                .padding(.top, 16)

            VStack(spacing: 16) {
                // Search Input Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(titleColor.opacity(0.6))

                    TextField("Cari Warna", text: $teksCari)
                        .autocorrectionDisabled()

                    Spacer()

                    Image(systemName: "mic.fill")
                        .foregroundStyle(titleColor.opacity(0.6))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white)
                .clipShape(Capsule())
                .padding(.horizontal, 20)

                // Recipe Color Cards 3-Column Grid
                ScrollView {
                    if daftar.isEmpty {
                        ContentUnavailableView(
                            "Belum ada warna",
                            systemImage: "book",
                            description: Text("Tambahkan warna di tab Warna dulu.")
                        )
                        .padding(.top, 40)
                    } else {
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 16),
                                GridItem(.flexible(), spacing: 16),
                                GridItem(.flexible(), spacing: 16)
                            ],
                            spacing: 16
                        ) {
                            ForEach(hasilCari) { resep in
                                Button {
                                    onSelect(resep)
                                    dismiss()
                                } label: {
                                    WarnaCardView(resep: resep)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .padding(.top, 10)
        }
        .background(sheetBg.ignoresSafeArea())
    }

    // MARK: - Header Bar

    private var modalHeaderBar: some View {
        HStack {
            Spacer()

            Text("Pilih Warna")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(titleColor)

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.7))
                    .frame(width: 36, height: 36)
                    .background(Color.black.opacity(0.08))
                    .clipShape(Circle())
            }
        }
    }
}

// MARK: - Previews

#Preview("Pilih Warna Sheet", traits: .landscapeLeft) {
    PilihResepSheetView { _ in }
        .modelContainer(for: SeronaSchema.models, inMemory: true)
}
