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
    private let assignedDeviceIDs: Set<UUID>

    private let oliveGreen = Color("oliveGreen")
    private let alertRed = Color(hex: "#DE2428")

    init(
        service: (any DeviceConnecting)? = nil,
        assignedDeviceIDs: Set<UUID> = [],
        onConnected: @escaping (DiscoveredDevice) -> Void = { _ in },
        onDisconnected: @escaping (DiscoveredDevice) -> Void = { _ in }
    ) {
        _viewModel = State(wrappedValue: DeviceListViewModel(service: service))
        self.assignedDeviceIDs = assignedDeviceIDs
        self.onConnected = onConnected
        self.onDisconnected = onDisconnected
    }

    var body: some View {
        VStack(spacing: 0) {
            modalHeaderBar
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 12)

            Group {
                if viewModel.devices.isEmpty, viewModel.connectedDevice == nil {
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
                            .buttonStyle(.borderedProminent)
                            .tint(oliveGreen)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            if let connected = viewModel.connectedDevice {
                                connectedRow(connected)
                                Divider()
                            }

                            ForEach(viewModel.devices.filter { $0.id != viewModel.connectedDevice?.id }) { device in
                                deviceRow(device)
                                Divider()
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                    }
                }
            }
            .padding(.vertical)
        }
        .background(Color.white)
        .presentationSizing(.form)
        .presentationBackground(Color.white)
        .presentationDragIndicator(.visible)
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
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .background(Color(UIColor.systemGray6))
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.06), radius: 3, x: 0, y: 1)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Tutup")

            Spacer()

            Text("Hubungkan Perangkat")
                .font(.headline.bold())
                .foregroundStyle(.primary)

            Spacer()

            Button {
                Task { await viewModel.scan() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .frame(width: 40, height: 40)
                    .background(Color(UIColor.systemGray6))
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.06), radius: 3, x: 0, y: 1)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isScanning || viewModel.connectingDevice != nil)
            .opacity((viewModel.isScanning || viewModel.connectingDevice != nil) ? 0.5 : 1)
            .accessibilityLabel("Cari Ulang Perangkat")
        }
    }

    // MARK: - Device Rows

    private func deviceRow(_ device: DiscoveredDevice) -> some View {
        let isAssigned = assignedDeviceIDs.contains(device.id)
        return HStack(spacing: 12) {
            Image(systemName: "wifi")
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)

            Text(device.nama)
                .font(.body)
                .foregroundStyle(.primary)

            Spacer()

            Button {
                Task { await viewModel.connect(device) }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isAssigned ? "lock.fill" : "plus")
                        .font(.caption.bold())
                    Text(isAssigned ? "Dipakai bak lain" : "Hubungkan")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(minHeight: 44)
                .background(oliveGreen, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isAssigned)
            .accessibilityHint(isAssigned ? "Perangkat sudah digunakan oleh bak aktif lain" : "")
        }
        .padding(.vertical, 14)
    }

    private func connectedRow(_ device: DiscoveredDevice) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "wifi")
                .font(.body.weight(.semibold))
                .foregroundStyle(oliveGreen)

            Text(device.nama)
                .font(.body.weight(.semibold))
                .foregroundStyle(oliveGreen)

            Spacer()

            Button {
                Task {
                    await viewModel.disconnect()
                    onDisconnected(device)
                }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(alertRed)
            }
            .buttonStyle(.plain)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel("Putuskan Perangkat")
        }
        .padding(.vertical, 14)
    }

    // MARK: - Alert Bindings

    private var connectingIsPresented: Binding<Bool> {
        Binding(
            get: { viewModel.connectingDevice != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.cancelConnecting()
                }
            }
        )
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.clearError()
                }
            }
        )
    }
}

// MARK: - Previews

#Preview("Device List Sheet", traits: .landscapeLeft) {
    BackgroundGradient()
        .sheet(isPresented: .constant(true)) {
            DeviceListSheetView(service: SimulatedDeviceConnectionService(discoveryDelay: .milliseconds(200)))
        }
}
