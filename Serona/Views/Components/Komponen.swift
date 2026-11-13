//
//  Komponen.swift
//  Serona
//
//  Created by Dina on 22/10/26.
//

import SwiftUI

extension Font {
    static var judulBold: Font {
        .system(.headline, weight: .bold)
    }

    static var labelBiasa: Font {
        .system(.headline)
    }
}

struct KolomTeks: View {
    let judul: String
    let placeholder: String
    @Binding var teks: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(judul)
                .font(.judulBold)
            TextField(placeholder, text: $teks)
                .textFieldStyle(.roundedBorder)
        }
    }
}

struct PemilihWarna: View {
    @Binding var warna: Color?

    private var bindingWarna: Binding<Color> {
        Binding(
            get: { warna ?? .blue },
            set: { warna = $0 }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Warna")
                .font(.judulBold)

            ZStack {
                if let terpilih = warna {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(terpilih)
                        .frame(height: 80)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(.secondary.opacity(0.3), lineWidth: 1)
                        )
                        .allowsHitTesting(false)
                } else {
                    Text("Pilih Warna")
                        .font(.judulBold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentColor, in: Capsule())
                        .allowsHitTesting(false)
                }

                ColorPicker("", selection: bindingWarna, supportsOpacity: false)
                    .labelsHidden()
                    .scaleEffect(x: 20, y: 3)
                    .opacity(0.02)

                if warna != nil {
                    Button {
                        warna = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white, .black.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: .topTrailing
                    )
                }
            }
            .frame(height: warna != nil ? 80 : nil)
            .clipShape(RoundedRectangle(cornerRadius: warna != nil ? 12 : 25))
        }
    }
}

struct BarisBahan: View {
    @Binding var kode: String
    @Binding var gram: Double?

    var body: some View {
        HStack(spacing: 8) {
            TextField("Kode / Nama Bahan", text: $kode)
                .textFieldStyle(.roundedBorder)

            TextField("0", value: $gram, format: .number)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .frame(width: 60)

            Text("g")
                .frame(width: 30)
        }
    }
}

enum UkuranKolom {
    static let lebarAngka: CGFloat = 85
    static let lebarSatuan: CGFloat = 24
    static let spasi: CGFloat = 12
    /// Lebar kolom angka kalau tidak ada satuan: menggantikan ruang satuan di kanan.
    static let lebarTanpaSatuan: CGFloat = lebarAngka + spasi + lebarSatuan
}

struct DaftarBahan: View {
    let judul: String
    let labelTambah: String
    @Binding var bahan: [BahanInput]
    let pilihanTersedia: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(judul)
                .font(.judulBold)

            ForEach($bahan) { $item in
                HStack(spacing: 12) {
                    Menu {
                        ForEach(pilihanTersedia, id: \.self) { opsi in
                            Button {
                                item.kode = opsi
                            } label: {
                                Text(opsi)
                                    .foregroundColor(.black)
                            }
                        }
                    } label: {
                        HStack {
                            Text(item.kode.isEmpty ? "Pilih Kode" : item.kode)
                                .foregroundColor(.black)
                                .lineLimit(1)

                            Spacer()

                            Image(systemName: "chevron.down")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.black)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .frame(maxWidth: .infinity)

                    TextField("0", value: $item.gram, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .frame(width: UkuranKolom.lebarAngka)

                    Text("gr")
                        .foregroundStyle(.primary)
                        .frame(width: UkuranKolom.lebarSatuan, alignment: .leading)
                }
            }

            Button {
                bahan.append(BahanInput())
            } label: {
                Label(labelTambah, systemImage: "plus")
                    .font(.judulBold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!bahan.semuaTerisi)
        }
    }
}

struct BarisIsian<Isian: View>: View {
    let label: String
    var satuan: String?
    var labelTebal = false
    @ViewBuilder let isian: Isian

    var body: some View {
        HStack {
            Text(label)
                .font(labelTebal ? .judulBold : .labelBiasa)

            Spacer()

            HStack(spacing: UkuranKolom.spasi) {
                isian

                if let satuan {
                    Text(satuan)
                        .frame(width: UkuranKolom.lebarSatuan, alignment: .leading)
                }
            }
        }
    }
}

struct BarisBatas: View {
    let label: String
    @Binding var nilai: Double?
    let rentang: ClosedRange<Double>

    var body: some View {
        BarisIsian(label: label) {
            TextField("0", value: $nilai, format: .number)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .frame(width: UkuranKolom.lebarTanpaSatuan)
                .onChange(of: nilai) { _, baru in
                    guard let baru else { return }
                    let terbatas = min(max(baru, rentang.lowerBound), rentang.upperBound)
                    if terbatas != baru {
                        nilai = terbatas
                    }
                }
        }
    }
}

struct BackgroundGradient: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(hex: "#FBEBC1"),
                Color(hex: "#F5D8CB")
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}
