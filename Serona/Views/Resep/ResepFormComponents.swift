import SwiftUI

struct SectionHeader: View {
    let title: String
    var tampilkanHapus: Bool = false
    var onHapus: () -> Void = {}

    var body: some View {
        HStack {
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(.primary)

            Spacer()

            if tampilkanHapus {
                Button(action: onHapus) {
                    Image(systemName: "trash")
                        .font(.title3)
                        .foregroundStyle(.red.opacity(0.85))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Hapus")
            }
        }
        .padding(.horizontal, 2)
        .padding(.top, 4)
    }
}

struct BahanCard: View {
    let labelKode: String
    @Binding var item: BahanInput
    let pilihan: [String]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(labelKode)
                    .font(.title3)
                    .foregroundStyle(.primary)

                Spacer()

                Menu {
                    ForEach(pilihan, id: \.self) { opsi in
                        Button(opsi) { item.kode = opsi }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(item.kode.isEmpty ? "Pilih" : item.kode)
                            .font(.title3)
                            .foregroundStyle(.gray)
                            .lineLimit(1)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.gray)
                    }
                }
            }
            .frame(height: 48)

            Divider()
                .overlay(Color.gray.opacity(0.5))
                .padding(.horizontal, 8)

            HStack {
                Text("Berat")
                    .font(.title3)
                    .foregroundStyle(.primary)

                Spacer()

                TextField("0", value: $item.gram, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(width: 90)

                Text("gr")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .frame(height: 48)
            .padding(.trailing, 8)
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 8)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
    }
}

struct TambahButton: View {
    let title: String
    var isEnabled: Bool = true
    let warna: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "plus.circle")
                    .font(.title2)
                Text(title)
                    .font(.title3)
                Spacer()
            }
            .foregroundStyle(isEnabled ? warna : Color.gray.opacity(0.6))
            .padding(.horizontal, 26)
            .frame(height: 60)
            .background(Color.white, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

struct JumlahAirCard: View {
    @Binding var ukuranAir: Int?

    var body: some View {
        HStack {
            Text("Jumlah Air")
                .font(.title3)
                .foregroundStyle(.primary)

            Spacer()

            Text("\(ukuranAir ?? 0) Liter")
                .font(.title3)
                .foregroundStyle(.primary)
                .monospacedDigit()

            HStack(spacing: 0) {
                Button {
                    let sekarang = ukuranAir ?? 0
                    if sekarang > 0 {
                        ukuranAir = sekarang - 1
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.body.weight(.bold))
                        .foregroundStyle(.primary)
                        .frame(width: 58, height: 40)
                }

                Rectangle()
                    .fill(Color.gray.opacity(0.35))
                    .frame(width: 1, height: 26)

                Button {
                    ukuranAir = (ukuranAir ?? 0) + 1
                } label: {
                    Image(systemName: "plus")
                        .font(.body.weight(.bold))
                        .foregroundStyle(.primary)
                        .frame(width: 58, height: 40)
                }
            }
            .background(Color(UIColor.systemGray5), in: Capsule())
            .buttonStyle(.plain)
        }
        .padding(.leading, 26)
        .padding(.trailing, 18)
        .frame(height: 70)
        .background(Color.white, in: Capsule())
    }
}
