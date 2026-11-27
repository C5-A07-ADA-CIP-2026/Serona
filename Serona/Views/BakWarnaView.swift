//
//  BakWarnaView.swift
//  Serona
//
//  Created by Steffany Florence on 25/11/26.
//

import SwiftUI

// MARK: - Bak Warna Grid & Empty State

struct BakWarnaContentView: View {
    @Binding var baks: [DummyBakItem]
    var onMulaiPindai: (DummyBakItem) -> Void
    var onSelesai: (DummyBakItem) -> Void
    var onPerbaikiLarutan: (DummyBakItem) -> Void
    var onTriggerWarningAlert: (DummyBakItem) -> Void

    var body: some View {
        if baks.isEmpty {
            emptyStateView
        } else {
            GeometryReader { proxy in
                let isLandscape = proxy.size.width > proxy.size.height
                let columnCount = isLandscape ? 3 : 2
                let columns = Array(
                    repeating: GridItem(.flexible(), spacing: 22),
                    count: columnCount
                )

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 22) {
                        ForEach(baks) { bak in
                            BakCardView(
                                bak: bak,
                                onMulaiPindai: { onMulaiPindai(bak) },
                                onSelesai: { onSelesai(bak) },
                                onPerbaikiLarutan: { onPerbaikiLarutan(bak) },
                                onTriggerWarningAlert: { onTriggerWarningAlert(bak) }
                            )
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

            Image("IconBakWarna")
                .resizable()
                .scaledToFit()
                .frame(width: 112, height: 112)

            VStack(spacing: 6) {
                Text("Tidak Ada Bak Warna")
                    .font(.title3.bold())
                    .foregroundStyle(Color(red: 0.63, green: 0.57, blue: 0.51))

                Text("Tekan tanda + untuk menambahkan bak")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(red: 0.63, green: 0.57, blue: 0.51))
            }

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Individual Bak Card

struct BakCardView: View {
    let bak: DummyBakItem
    var onMulaiPindai: () -> Void
    var onSelesai: () -> Void
    var onPerbaikiLarutan: () -> Void
    var onTriggerWarningAlert: () -> Void

    private var isConnected: Bool {
        bak.isAktif && bak.isTerhubung
    }

    private var kepekatanDisplay: String {
        guard bak.stage == .active || bak.stage == .activeWarning else { return "-" }
        return "\(bak.kepekatan)%"
    }

    private var phDisplay: String {
        guard bak.stage == .active || bak.stage == .activeWarning else { return "-" }
        return bak.phAir.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", bak.phAir)
            : String(format: "%.1f", bak.phAir)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header: Bak Name + Terhubung / Tidak Terhubung
            HStack {
                Text(bak.nama)
                    .font(.title2.bold())
                    .foregroundStyle(.black)

                Spacer()

                HStack(spacing: 6) {
                    Circle()
                        .fill(isConnected ? Color.green : Color.gray.opacity(0.85))
                        .frame(width: 8, height: 8)
                    Text(isConnected ? "Terhubung" : "Tidak Terhubung")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Color swatch + Color Name + Nama Pemesan
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(bak.isAktif ? Color(dummyHex: bak.warnaHex) : Color.gray.opacity(0.85))
                    .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text(bak.isAktif ? bak.namaWarna : "-")
                        .font(.headline.bold())
                        .foregroundStyle(.black)

                    Text(bak.isAktif ? bak.namaPemesan : "-")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            // Status Pill Banner (tappable when in warning to launch repair guide)
            Button {
                if bak.stage == .activeWarning {
                    onPerbaikiLarutan()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: statusIcon)
                        .font(.subheadline)
                    Text(statusMessage)
                        .font(.caption.weight(.semibold))
                    Spacer()
                }
                .foregroundStyle(statusForeground)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(statusBackground, in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .disabled(bak.stage != .activeWarning)

            // Metrics Tiles
            HStack(spacing: 12) {
                metricTile(
                    icon: "allergens",
                    title: "Kepekatan",
                    value: kepekatanDisplay,
                    isWarning: bak.isConcentrationLow
                )
                metricTile(
                    icon: "drop",
                    title: "pH Air",
                    value: phDisplay,
                    isWarning: bak.isPHLow
                )
            }

            // Bottom Action Row
            HStack {
                Button {
                    if bak.stage == .inactive || bak.stage == .disconnected {
                        onMulaiPindai()
                    } else {
                        onSelesai()
                    }
                } label: {
                    Text(bak.stage == .inactive || bak.stage == .disconnected ? "Mulai Pindai" : "Selesai")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 36)
                        .padding(.vertical, 12)
                        .frame(minHeight: 44)
                        .background(SeronaTheme.oliveGreen, in: Capsule())
                }
                .buttonStyle(.plain)

                Spacer()

                // Optional demo menu to test quality alert / disconnect without sensors
                if bak.isAktif {
                    Menu {
                        if bak.isTerhubung {
                            Button("Simulasikan Kualitas Menurun", role: .destructive) {
                                bak.kepekatan = 87
                                bak.phAir = 10.0
                                onTriggerWarningAlert()
                            }
                            Button("Simulasikan Putus Koneksi") {
                                bak.isTerhubung = false
                            }
                        } else {
                            Button("Sambungkan Kembali") {
                                bak.isTerhubung = true
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                            .padding(10)
                    }
                }
            }
        }
        .padding(20)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 22))
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
    }

    private func metricTile(icon: String, title: String, value: String, isWarning: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(SeronaTheme.oliveGreenText)

            Text(value)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(isWarning ? SeronaTheme.warningRed : .black)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(SeronaTheme.modalBackground, in: RoundedRectangle(cornerRadius: 14))
    }

    private var statusIcon: String {
        switch bak.stage {
        case .active: "checkmark.circle.fill"
        case .activeWarning: "exclamationmark.triangle.fill"
        case .inactive, .disconnected: "questionmark.circle.fill"
        }
    }

    private var statusMessage: String {
        switch bak.stage {
        case .active: "Kualitas Larutan Baik"
        case .activeWarning: "Kualitas Larutan Menurun"
        case .inactive, .disconnected: "Tidak ada data yang terbaca"
        }
    }

    private var statusForeground: Color {
        switch bak.stage {
        case .active: SeronaTheme.oliveGreenText
        case .activeWarning: Color(red: 0.78, green: 0.10, blue: 0.11)
        case .inactive, .disconnected: Color.primary.opacity(0.65)
        }
    }

    private var statusBackground: Color {
        switch bak.stage {
        case .active: SeronaTheme.oliveGreen.opacity(0.12)
        case .activeWarning: Color.red.opacity(0.12)
        case .inactive, .disconnected: Color.gray.opacity(0.12)
        }
    }
}

// MARK: - Centered Setup Modal (Bak Setup -> Hubungkan Perangkat -> Warna Picker)

struct BakSetupModalView: View {
    enum Step {
        case mainForm
        case connectDevice
        case pickColor
    }

    let bak: DummyBakItem
    @Binding var reseps: [DummyResepItem]
    let onClose: () -> Void
    let onComplete: () -> Void

    @State private var currentStep: Step = .mainForm
    @State private var connectedDevice: String? = nil
    @State private var connectingDevice: String? = nil
    @State private var selectedResep: DummyResepItem? = nil
    @State private var tempSelectedResep: DummyResepItem? = nil
    @State private var namaPemesan: String = ""
    @State private var jumlahAir: Int = 0

    private let dummyDevices = [
        "ESP 32 - A",
        "ESP 32 - B",
        "ESP 32 - C",
        "ESP 32 - D",
        "ESP 32 - E",
        "ESP 32 - F"
    ]

    private var isFormReady: Bool {
        connectedDevice != nil && selectedResep != nil
    }

    var body: some View {
        Group {
            switch currentStep {
            case .mainForm:
                mainFormCard
            case .connectDevice:
                connectDeviceCard
            case .pickColor:
                pickColorCard
            }
        }
        .frame(width: 480)
        .background(SeronaTheme.modalBackground, in: RoundedRectangle(cornerRadius: 28))
        .shadow(color: .black.opacity(0.15), radius: 24, x: 0, y: 12)
    }

    // Step 1: Main Form ("Bak 1")
    private var mainFormCard: some View {
        VStack(spacing: 16) {
            // Header
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

                Text(bak.nama)
                    .font(.headline.bold())

                Spacer()

                Button {
                    saveAndStart()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(isFormReady ? SeronaTheme.oliveGreen : Color.gray, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(!isFormReady)
            }
            .padding(.bottom, 6)

            // Row 1: Perangkat
            Button {
                currentStep = .connectDevice
            } label: {
                HStack {
                    Text("Perangkat")
                        .foregroundStyle(.black)
                    Spacer()
                    if let connectedDevice {
                        Text(connectedDevice)
                            .foregroundStyle(.black)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 18)
                .frame(height: 52)
                .background(Color.white, in: Capsule())
            }
            .buttonStyle(.plain)

            // Row 2: Warna
            Button {
                tempSelectedResep = selectedResep
                currentStep = .pickColor
            } label: {
                HStack {
                    Text("Warna")
                        .foregroundStyle(.black)
                    Spacer()
                    if let selectedResep {
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(dummyHex: selectedResep.warnaHex ?? "#A33240"))
                                .frame(width: 18, height: 18)
                            Text(selectedResep.namaWarna)
                                .foregroundStyle(.black)
                        }
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 18)
                .frame(height: 52)
                .background(Color.white, in: Capsule())
            }
            .buttonStyle(.plain)

            // Row 3: Nama Pemesan
            TextField("Nama Pemesan", text: $namaPemesan)
                .padding(.horizontal, 18)
                .frame(height: 52)
                .background(Color.white, in: Capsule())

            // Row 4: Jumlah Air
            HStack {
                Text("Jumlah Air")
                    .foregroundStyle(.black)

                Spacer()

                Text("\(jumlahAir) Liter")
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
        }
        .padding(24)
    }

    // Step 2: Hubungkan Perangkat (Matches Screenshots 3 & 4)
    private var connectDeviceCard: some View {
        ZStack {
            VStack(spacing: 16) {
                HStack {
                    Button {
                        currentStep = .mainForm
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.black)
                            .frame(width: 40, height: 40)
                            .background(Color.white, in: Circle())
                            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text("Hubungkan Perangkat")
                        .font(.headline.bold())

                    Spacer()

                    Button {
                        // Visual refresh trigger
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.black)
                            .frame(width: 40, height: 40)
                            .background(Color.white, in: Circle())
                            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                }

                VStack(spacing: 0) {
                    ForEach(Array(dummyDevices.enumerated()), id: \.offset) { index, device in
                        HStack(spacing: 10) {
                            if connectedDevice == device {
                                Image(systemName: "checkmark")
                                    .font(.caption.bold())
                                    .foregroundStyle(SeronaTheme.oliveGreen)
                            }

                            Text(device)
                                .font(.subheadline)
                                .foregroundStyle(.black)

                            Spacer()

                            if connectedDevice == device {
                                Button {
                                    connectedDevice = nil
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(SeronaTheme.warningRed)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 46)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            startDummyConnection(to: device)
                        }

                        if index < dummyDevices.count - 1 {
                            Divider()
                                .padding(.leading, 14)
                        }
                    }
                }
                .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(24)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 28))

            // "Menghubungkan..." Dialog Overlay (Matches Screenshot 3 right)
            if let targetDevice = connectingDevice {
                Color.black.opacity(0.18)
                    .clipShape(RoundedRectangle(cornerRadius: 28))

                VStack(alignment: .leading, spacing: 14) {
                    Text(targetDevice)
                        .font(.headline.bold())
                        .foregroundStyle(.black)

                    Text("Menghubungkan...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button {
                        connectingDevice = nil
                    } label: {
                        Text("Batalkan")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color.gray.opacity(0.85), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .padding(22)
                .frame(width: 270)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 24))
                .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 6)
            }
        }
    }

    // Step 3: Warna Grid Picker (Matches Screenshot 5)
    private var pickColorCard: some View {
        let availableReseps = reseps.filter { $0.warnaHex != nil }

        return VStack(spacing: 16) {
            HStack {
                Button {
                    currentStep = .mainForm
                } label: {
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

                Spacer()

                Button {
                    selectedResep = tempSelectedResep
                    currentStep = .mainForm
                } label: {
                    Image(systemName: "checkmark")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(tempSelectedResep != nil ? SeronaTheme.oliveGreen : Color.gray, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(tempSelectedResep == nil)
            }

            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)],
                    spacing: 14
                ) {
                    ForEach(availableReseps) { resep in
                        let isSelected = tempSelectedResep?.id == resep.id
                        VStack(alignment: .leading, spacing: 10) {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(dummyHex: resep.warnaHex ?? "#A33240"))
                                .frame(height: 125)

                            Text(resep.namaWarna)
                                .font(.headline.bold())
                                .foregroundStyle(.black)
                        }
                        .padding(12)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(isSelected ? SeronaTheme.oliveGreen : Color.clear, lineWidth: 2.5)
                        )
                        .onTapGesture {
                            tempSelectedResep = resep
                        }
                    }
                }
            }
            .frame(maxHeight: 340)
        }
        .padding(24)
    }

    private func startDummyConnection(to device: String) {
        connectingDevice = device
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            if connectingDevice == device {
                connectingDevice = nil
                connectedDevice = device
            }
        }
    }

    private func saveAndStart() {
        guard let device = connectedDevice, let resep = selectedResep else { return }
        let trimmedCustomer = namaPemesan.trimmingCharacters(in: .whitespacesAndNewlines)

        bak.perangkatNama = device
        bak.namaWarna = resep.namaWarna
        bak.warnaHex = resep.warnaHex ?? "#A33240"
        bak.kodePewarna = resep.primaryKodePewarna
        bak.kodeSoda = resep.primaryKodeSoda
        bak.batasKepekatan = resep.batasKepekatan
        bak.batasPH = resep.batasPH
        bak.namaPemesan = trimmedCustomer.isEmpty ? "Bu Wati" : trimmedCustomer
        bak.jumlahAirLiter = jumlahAir > 0 ? jumlahAir : 50
        bak.kepekatan = 100
        bak.phAir = 13.0
        bak.hasShownAutoAlert = false
        bak.isAktif = true
        bak.isTerhubung = true

        onComplete()
    }
}
