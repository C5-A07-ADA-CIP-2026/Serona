//
//  DeviceListSheetView.swift
//  Serona
//

import SwiftUI

struct DeviceListSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: DeviceListViewModel
    private let onConnected: (DiscoveredDevice) -> Void
    private let onDisconnected: (DiscoveredDevice) -> Void

    private let titleColor = Color(red: 0.38, green: 0.15, blue: 0.15)
    private let oliveGreen = Color(red: 0.35, green: 0.42, blue: 0.25)
    private let sheetBg = Color(red: 0.98, green: 0.97, blue: 0.93)

    init(
        service: (any DeviceConnecting)? = nil,
        onConnected: @escaping (DiscoveredDevice) -> Void = { _ in },
        onDisconnected: @escaping (DiscoveredDevice) -> Void = { _ in }
    ) {
        _viewModel = State(wrappedValue: DeviceListViewModel(service: service))
        self.onConnected = onConnected
        self.onDisconnected = onDisconnected
    }

    var body: some View {
        VStack(spacing: 0) {
            // Modal Header Bar (X left, Title center, Refresh right)
            modalHeaderBar
                .padding(.horizontal, 20)
                .padding(.top, 16)

            VStack {
                if viewModel.devices.isEmpty && viewModel.connectedDevice == nil {
                    if viewModel.isScanning {
                        ProgressView("Mencari perangkat…")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ContentUnavailableView {
                            Label("Perangkat tidak ditemukan", systemImage: "antenna.radiowaves.left.and.right.slash")
                        } description: {
                            Text("Nyalakan perangkat dan Bluetooth, lalu cari ulang.")
                        } actions: {
                            Button("Cari Ulang") {
                                Task { await viewModel.scan() }
                            }
                        }
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            if let connected = viewModel.connectedDevice {
                                connectedRow(connected)
                            }

                            ForEach(viewModel.devices.filter { $0.id != viewModel.connectedDevice?.id }) { device in
                                deviceRow(device)
                            }
                        }
                        .padding(20)
                    }
                }
            }
        }
        .background(sheetBg.ignoresSafeArea())
        .task {
            await viewModel.scan()
        }
        .onChange(of: viewModel.connectedDevice) { _, device in
            guard let device else { return }
            onConnected(device)
            dismiss()
        }
        .alert(
            viewModel.connectingDevice?.nama ?? "Perangkat",
            isPresented: connectingIsPresented
        ) {
            Button("Batalkan", role: .cancel) { viewModel.cancelConnecting() }
        } message: {
            Text("Menghubungkan…")
        }
        .alert(
            "Perangkat",
            isPresented: errorIsPresented,
            presenting: viewModel.errorMessage
        ) { _ in
            Button("Tutup", role: .cancel) {}
        } message: { message in
            Text(message)
        }
    }

    // MARK: - Header Bar

    private var modalHeaderBar: some View {
        HStack {
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

            Spacer()

            Text("Tambahkan Perangkat")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(titleColor)

            Spacer()

            Button {
                Task { await viewModel.scan() }
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(oliveGreen)
                    .clipShape(Circle())
            }
            .disabled(viewModel.isScanning || viewModel.connectingDevice != nil)
        }
    }

    // MARK: - Device Rows

    private func deviceRow(_ device: DiscoveredDevice) -> some View {
        HStack {
            Image(systemName: "wifi")
                .foregroundStyle(titleColor)

            Text(device.nama)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(titleColor)

            Spacer()

            Button {
                Task { await viewModel.connect(device) }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                    Text("Hubungkan")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(oliveGreen)
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func connectedRow(_ device: DiscoveredDevice) -> some View {
        HStack {
            Image(systemName: "wifi")
                .foregroundStyle(oliveGreen)

            Text(device.nama)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(oliveGreen)

            Spacer()

            Button {
                Task {
                    await viewModel.disconnect()
                    onDisconnected(device)
                }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var connectingIsPresented: Binding<Bool> {
        Binding(
            get: { viewModel.connectingDevice != nil },
            set: { isPresented in
                if !isPresented { viewModel.cancelConnecting() }
            }
        )
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { isPresented in
                if !isPresented { viewModel.clearError() }
            }
        )
    }
}

// MARK: - Previews

#Preview("Device List Sheet", traits: .landscapeLeft) {
    DeviceListSheetView(service: SimulatedDeviceConnectionService(discoveryDelay: .milliseconds(200)))
}
