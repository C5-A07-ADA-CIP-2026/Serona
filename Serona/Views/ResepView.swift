//
//  ResepView.swift
//  Serona
//
//  Created by Steffany Florence on 25/11/26.
//

import SwiftUI

struct ResepWarnaContentView: View {
    let reseps: [DummyResepItem]
    let onSelectResep: (DummyResepItem) -> Void

    var body: some View {
        if reseps.isEmpty {
            emptyStateView
        } else {
            GeometryReader { proxy in
                let isLandscape = proxy.size.width > proxy.size.height
                let columnCount = isLandscape ? 4 : 2
                let columns = Array(
                    repeating: GridItem(.flexible(), spacing: 24),
                    count: columnCount
                )

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(reseps) { resep in
                            ResepCardView(resep: resep)
                                .onTapGesture {
                                    onSelectResep(resep)
                                }
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 32)
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 14) {
            Spacer()

            Image("IconResepWarna")
                .resizable()
                .scaledToFit()
                .frame(width: 112, height: 112)

            VStack(spacing: 6) {
                Text("Tidak Ada Resep Warna")
                    .font(.title3.bold())
                    .foregroundStyle(Color(red: 0.63, green: 0.57, blue: 0.51))

                Text("Tekan tanda + untuk menambahkan resep")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(red: 0.63, green: 0.57, blue: 0.51))
            }

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ResepCardView: View {
    let resep: DummyResepItem

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let hex = resep.warnaHex {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(dummyHex: hex))
                    .aspectRatio(1.05, contentMode: .fit)
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0.90, green: 0.90, blue: 0.92))
                    .aspectRatio(1.05, contentMode: .fit)
                    .overlay {
                        VStack(spacing: 10) {
                            Image(systemName: "photo")
                                .font(.system(size: 38))
                                .foregroundStyle(Color.gray.opacity(0.8))

                            Text("Warna akan muncul\nsetelah digunakan")
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(Color.gray.opacity(0.85))
                        }
                        .padding(12)
                    }
            }

            Text(resep.namaWarna)
                .font(.title3.bold())
                .foregroundStyle(.black)
                .padding(.bottom, 6)
        }
        .padding(14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 22))
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Centered "Warna" Recipe Modal (Create & Edit Pre-filled Data)

struct ResepFormModalView: View {
    let existingResep: DummyResepItem?
    let onClose: () -> Void
    let onSave: (DummyResepItem) -> Void

    @State private var namaWarna: String
    @State private var jumlahAir: Int
    @State private var napthols: [DummyNaptholEntry]
    @State private var zatPembantu: [DummyZatPembantuEntry]

    private let availableNaptholCodes = ["AS-G", "AS-LB", "AS-", "AS-D", "AS-OL", "AS-BS", "AS-BO", "AS-BR", "AS-GR", "Soga 91"]
    private let availableSodaTypes = ["Abu", "Kostik"]

    init(
        existingResep: DummyResepItem?,
        onClose: @escaping () -> Void,
        onSave: @escaping (DummyResepItem) -> Void
    ) {
        self.existingResep = existingResep
        self.onClose = onClose
        self.onSave = onSave

        _namaWarna = State(initialValue: existingResep?.namaWarna ?? "")
        _jumlahAir = State(initialValue: existingResep?.volumeAirLiter ?? 0)
        _napthols = State(
            initialValue: existingResep?.napthols ?? [
                DummyNaptholEntry(kodePewarna: "AS", beratGram: 0)
            ]
        )
        _zatPembantu = State(
            initialValue: existingResep?.zatPembantu ?? [
                DummyZatPembantuEntry(jenisSoda: "Abu", beratGram: 0)
            ]
        )
    }

    private var isSaveEnabled: Bool {
        !namaWarna.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header: Close (×), "Warna", Save (✓)
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.black)
                        .frame(width: 40, height: 40)
                        .background(Color.white, in: Circle())
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)

                Spacer()

                Text("Warna")
                    .font(.headline.bold())
                    .foregroundStyle(.black)

                Spacer()

                Button {
                    saveResep()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(isSaveEnabled ? SeronaTheme.oliveGreen : Color.gray, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(!isSaveEnabled)
            }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    // Row 1: Nama Warna
                    HStack {
                        Text("Nama Warna")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.black)

                        Spacer()

                        TextField("Nama Warna", text: $namaWarna)
                            .multilineTextAlignment(.trailing)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 18)
                    .frame(height: 52)
                    .background(Color.white, in: Capsule())

                    // Row 2: Jumlah Air
                    HStack {
                        Text("Jumlah Air")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.black)

                        Spacer()

                        Text("\(jumlahAir) Liter")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.black)
                            .padding(.trailing, 8)

                        HStack(spacing: 0) {
                            Button {
                                if jumlahAir > 0 { jumlahAir -= 1 }
                            } label: {
                                Image(systemName: "minus")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(width: 42, height: 32)
                            }
                            .buttonStyle(.plain)

                            Divider().frame(height: 18)

                            Button {
                                jumlahAir += 1
                            } label: {
                                Image(systemName: "plus")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(width: 42, height: 32)
                            }
                            .buttonStyle(.plain)
                        }
                        .background(SeronaTheme.modalBackground, in: Capsule())
                    }
                    .padding(.horizontal, 18)
                    .frame(height: 52)
                    .background(Color.white, in: Capsule())

                    // Dynamic Napthol Sections ("Napthol 1", "Napthol 2", ...)
                    ForEach(Array(napthols.enumerated()), id: \.element.id) { index, _ in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Napthol \(index + 1)")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.black)

                                Spacer()

                                if index > 0 {
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.18)) {
                                            napthols.remove(at: index)
                                        }
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.subheadline)
                                            .foregroundStyle(SeronaTheme.warningRed)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            VStack(spacing: 0) {
                                // Kode Pewarna Picker Row
                                HStack {
                                    Text("Kode Pewarna")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.black)

                                    Spacer()

                                    Picker("Kode Pewarna", selection: $napthols[index].kodePewarna) {
                                        ForEach(availableNaptholCodes, id: \.self) { code in
                                            Text(code).tag(code)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(.secondary)
                                }
                                .padding(.horizontal, 18)
                                .frame(height: 48)

                                Divider()
                                    .padding(.horizontal, 18)

                                // Berat Input Row
                                HStack {
                                    Text("Berat")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.black)

                                    Spacer()

                                    HStack(spacing: 4) {
                                        TextField("0", value: $napthols[index].beratGram, format: .number)
                                            .keyboardType(.numberPad)
                                            .multilineTextAlignment(.trailing)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .frame(width: 64)

                                        Text("gr")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.horizontal, 18)
                                .frame(height: 48)
                            }
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 20))
                        }
                    }

                    // "+ Tambah Napthol" Button
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            napthols.append(DummyNaptholEntry(kodePewarna: "ASG", beratGram: 100))
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "plus.circle")
                                .font(.body.weight(.medium))
                            Text("Tambah Napthol")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                        }
                        .foregroundStyle(SeronaTheme.oliveGreenText)
                        .padding(.horizontal, 18)
                        .frame(height: 50)
                        .background(Color.white, in: Capsule())
                    }
                    .buttonStyle(.plain)

                    // Zat Pembantu Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Zat Pembantu")
                            .font(.subheadline.bold())
                            .foregroundStyle(.black)

                        ForEach(Array(zatPembantu.enumerated()), id: \.element.id) { index, _ in
                            VStack(spacing: 0) {
                                HStack {
                                    Text("Soda")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.black)

                                    Spacer()

                                    Picker("Soda", selection: $zatPembantu[index].jenisSoda) {
                                        ForEach(availableSodaTypes, id: \.self) { soda in
                                            Text(soda).tag(soda)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(.secondary)

                                    if index > 0 {
                                        Button {
                                            withAnimation(.easeInOut(duration: 0.18)) {
                                                zatPembantu.remove(at: index)
                                            }
                                        } label: {
                                            Image(systemName: "trash")
                                                .font(.caption)
                                                .foregroundStyle(SeronaTheme.warningRed)
                                        }
                                        .buttonStyle(.plain)
                                        .padding(.leading, 6)
                                    }
                                }
                                .padding(.horizontal, 18)
                                .frame(height: 48)

                                Divider()
                                    .padding(.horizontal, 18)

                                HStack {
                                    Text("Berat")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.black)

                                    Spacer()

                                    HStack(spacing: 4) {
                                        TextField("0", value: $zatPembantu[index].beratGram, format: .number)
                                            .keyboardType(.numberPad)
                                            .multilineTextAlignment(.trailing)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .frame(width: 64)

                                        Text("gr")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.horizontal, 18)
                                .frame(height: 48)
                            }
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 20))
                        }
                    }

                    // "+ Tambah Zat Pembantu" Button
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            zatPembantu.append(DummyZatPembantuEntry(jenisSoda: "Kostik", beratGram: 100))
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "plus.circle")
                                .font(.body.weight(.medium))
                            Text("Tambah Zat Pembantu")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                        }
                        .foregroundStyle(SeronaTheme.oliveGreenText)
                        .padding(.horizontal, 18)
                        .frame(height: 50)
                        .background(Color.white, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 8)
            }
            .frame(maxHeight: 540)
        }
        .padding(24)
        .frame(width: 480)
        .background(SeronaTheme.modalBackground, in: RoundedRectangle(cornerRadius: 28))
        .shadow(color: .black.opacity(0.15), radius: 24, x: 0, y: 12)
    }

    private func saveResep() {
        let trimmedName = namaWarna.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let result = DummyResepItem(
            namaWarna: trimmedName,
            warnaHex: existingResep?.warnaHex, // Preserves existing color swatch or keeps nil until used
            volumeAirLiter: jumlahAir,
            napthols: napthols,
            zatPembantu: zatPembantu,
            batasKepekatan: existingResep?.batasKepekatan ?? 90,
            batasPH: existingResep?.batasPH ?? 11.0
        )
        onSave(result)
    }
}
