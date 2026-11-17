//
//  PilihWarnaSheetView.swift
//  Serona
//

import SwiftData
import SwiftUI

// MARK: - Pilih Warna Sub-Sheet

struct PilihWarnaSheetView: View {
    @Query(sort: \Resep.dibuat, order: .reverse) private var daftarResep: [Resep]
    @Environment(\.dismiss) private var dismiss

    @State private var chosenResep: Resep?

    var onConfirm: (Resep) -> Void

    private let oliveGreen = Color("oliveGreen")

    init(selectedResep: Resep?, onConfirm: @escaping (Resep) -> Void) {
        _chosenResep = State(initialValue: selectedResep)
        self.onConfirm = onConfirm
    }

    var body: some View {
        VStack(spacing: 16) {
            headerBar

            if daftarResep.isEmpty {
                ContentUnavailableView(
                    "Belum ada resep warna",
                    image: "IconResepWarna",
                    description: Text("Tambahkan resep terlebih dahulu di tab Resep Warna.")
                )
                .foregroundColor(Color(hex: "#B89B8D"))
                .frame(minHeight: 360)
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 20),
                            GridItem(.flexible(), spacing: 20),
                        ],
                        spacing: 20
                    ) {
                        ForEach(daftarResep) { resep in
                            resepCard(for: resep)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 4)
                    .padding(.bottom, 24)
                }
            }
        }
        .background(Color.white)
        .presentationSizing(.form)
        .presentationBackground(Color.white)
        .presentationDragIndicator(.visible)
    }

    private var headerBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .background(Color(UIColor.systemGray5))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Tutup")

            Spacer()

            Text("Pilih Warna")
                .font(.headline.bold())
                .foregroundStyle(.primary)

            Spacer()

            Button {
                if let chosenResep {
                    onConfirm(chosenResep)
                    dismiss()
                }
            } label: {
                Image(systemName: "checkmark")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(chosenResep != nil ? oliveGreen : Color.gray.opacity(0.6))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(chosenResep == nil)
            .accessibilityLabel("Konfirmasi Warna")
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
    }

    private func resepCard(for resep: Resep) -> some View {
        let isSelected = chosenResep?.persistentModelID == resep.persistentModelID

        return Button {
            chosenResep = resep
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                if let hex = resep.warnaHex, !hex.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: hex))
                        .aspectRatio(1, contentMode: .fit)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(UIColor.systemGray5))
                            .aspectRatio(1, contentMode: .fit)

                        VStack(spacing: 8) {
                            Image(systemName: "photo")
                                .font(.system(size: 36))
                                .foregroundStyle(Color.gray.opacity(0.75))

                            Text("Warna akan muncul\nsetelah digunakan")
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(Color.gray)
                        }
                        .padding(8)
                    }
                }

                Text(resep.namaWarna)
                    .font(.headline.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .padding(14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isSelected ? oliveGreen : Color.clear, lineWidth: 2.5)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }
}

#Preview("Pilih Warna Sheet", traits: .landscapeLeft) {
    let container = SeronaSchema.makePreviewContainer()
    let context = container.mainContext

    let samples: [(nama: String, hex: String?)] = [
        ("Ungu Muda", "#AC4574"),
        ("Marun", nil),
        ("Ungu Tua", "#933C64"),
        ("Merah Bata", "#A63743"),
    ]
    for (offset, sample) in samples.enumerated() {
        context.insert(Resep(
            namaWarna: sample.nama, warnaHex: sample.hex, air: 1000, kepekatan: 90, batasPH: 11,
            dibuat: .now.addingTimeInterval(TimeInterval(offset + 1))
        ))
    }

    return BackgroundGradient()
        .sheet(isPresented: .constant(true)) {
            PilihWarnaSheetView(selectedResep: nil) { _ in }
        }
        .modelContainer(container)
}
