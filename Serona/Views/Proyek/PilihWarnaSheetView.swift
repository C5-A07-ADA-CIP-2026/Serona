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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var chosenResep: Resep?

    var onConfirm: (Resep) -> Void
    /// True when pushed inside a `NavigationStack`: the system bar replaces the custom header and Back button.
    let isPushed: Bool

    private let oliveGreen = Color("oliveGreen")

    init(selectedResep: Resep?, isPushed: Bool = false, onConfirm: @escaping (Resep) -> Void) {
        _chosenResep = State(initialValue: selectedResep)
        self.isPushed = isPushed
        self.onConfirm = onConfirm
    }

    var body: some View {
        VStack(spacing: 16) {
            if !isPushed {
                headerBar
            }

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
                        // One column at accessibility sizes so names and the placeholder text have room.
                        columns: Array(
                            repeating: GridItem(.flexible(), spacing: 20),
                            count: dynamicTypeSize.isAccessibilitySize ? 1 : 2
                        ),
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
        .modalSheetStyle(isEnabled: !isPushed)
        .navigationTitle("Warna")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isPushed {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Konfirmasi Warna", systemImage: "checkmark") {
                        if let chosenResep {
                            onConfirm(chosenResep)
                            dismiss()
                        }
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderedProminent)
                    .tint(oliveGreen)
                    .disabled(chosenResep == nil)
                }
            }
        }
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

            Text("Warna")
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

    /// Stands in for the color swatch of a recipe that has no color yet. Square at normal sizes; at accessibility
    /// sizes it grows with its text instead of clipping or overflowing it.
    private var placeholderTile: some View {
        let content = VStack(spacing: 8) {
            Image(systemName: "photo")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("Warna akan muncul\nsetelah digunakan")
                .font(.caption)
                .multilineTextAlignment(.center)
                // Primary at reduced opacity keeps this above 4.5:1 on the gray tile; plain gray was about 2.4:1.
                .foregroundStyle(.primary.opacity(0.75))
        }
        .padding(8)
        .frame(maxWidth: .infinity)

        return Group {
            if dynamicTypeSize.isAccessibilitySize {
                content
                    .padding(.vertical, 12)
                    .background(Color(UIColor.systemGray5), in: RoundedRectangle(cornerRadius: 12))
            } else {
                Color(UIColor.systemGray5)
                    .aspectRatio(1, contentMode: .fit)
                    .overlay { content }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
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
                    placeholderTile
                }

                Text(resep.namaWarna)
                    .font(.headline.bold())
                    .foregroundStyle(.primary)
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
