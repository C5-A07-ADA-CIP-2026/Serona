import SwiftUI

struct DeviceListSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var viewModel: DeviceListViewModel
    private let onConnected: (DiscoveredDevice) -> Void
    private let onDisconnected: (DiscoveredDevice) -> Void
    private let assignedDeviceIDs: Set<UUID>

    private let isPushed: Bool

    private static let rowInsets = EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)

    private let oliveGreen = Color("oliveGreen")
    private let alertRed = Color(hex: "#DE2428")

    init(
        service: (any DeviceConnecting)? = nil,
        assignedDeviceIDs: Set<UUID> = [],
        connectedDevice: DiscoveredDevice? = nil,
        isPushed: Bool = false,
        onConnected: @escaping (DiscoveredDevice) -> Void = { _ in },
        onDisconnected: @escaping (DiscoveredDevice) -> Void = { _ in }
    ) {
        _viewModel = State(wrappedValue: DeviceListViewModel(service: service, connectedDevice: connectedDevice))
        self.assignedDeviceIDs = assignedDeviceIDs
        self.isPushed = isPushed
        self.onConnected = onConnected
        self.onDisconnected = onDisconnected
    }

    var body: some View {
        VStack(spacing: 0) {
            if !isPushed {
                modalHeaderBar
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 12)
            }

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
                    List {
                        if let connected = viewModel.connectedDevice {
                            connectedRow(connected)
                                .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                                .listRowInsets(Self.rowInsets)
                        }

                        ForEach(viewModel.devices.filter { $0.id != viewModel.connectedDevice?.id }) { device in
                            deviceRow(device)
                                .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                                .listRowInsets(Self.rowInsets)
                        }
                    }
                    .listStyle(.plain)
                }
            }
        }
        .background(Color.white)
        .modalSheetStyle(isEnabled: !isPushed)
        .navigationTitle("Hubungkan Perangkat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isPushed {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cari Ulang Perangkat", systemImage: "arrow.clockwise") {
                        Task { await viewModel.scan() }
                    }
                    .labelStyle(.iconOnly)
                    .disabled(viewModel.isScanning || viewModel.connectingDevice != nil)
                }
            }
        }
        .task {
            await viewModel.scan()
        }
        .onChange(of: viewModel.connectedDevice) { _, device in
            guard let device else { return }
            onConnected(device)

            if !isPushed {
                dismiss()
            }
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
                    .frame(width: 44, height: 44)
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

    @ViewBuilder
    private func deviceRow(_ device: DiscoveredDevice) -> some View {
        if assignedDeviceIDs.contains(device.id) {
            deviceRowContent(device, isAssigned: true)
                .accessibilityElement(children: .combine)
                .accessibilityHint("Perangkat sudah digunakan oleh bak aktif lain")
        } else {
            Button {
                Task { await viewModel.connect(device) }
            } label: {
                deviceRowContent(device, isAssigned: false)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Menghubungkan perangkat")
        }
    }

    private func deviceRowContent(_ device: DiscoveredDevice, isAssigned: Bool) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            Text(device.nama)
                .font(.body)
                .foregroundStyle(isAssigned ? .secondary : .primary)

            if !dynamicTypeSize.isAccessibilitySize {
                Spacer()
            }

            if isAssigned {
                Label("Dipakai bak lain", systemImage: "lock.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func connectedRow(_ device: DiscoveredDevice) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.oliveGreenText)
                .accessibilityHidden(true)

            Text(device.nama)
                .font(.body)
                .foregroundStyle(.primary)

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
            .buttonStyle(.borderless)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel("Putuskan Perangkat")
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .contain)
    }

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

#Preview("Device List Sheet", traits: .landscapeLeft) {
    BackgroundGradient()
        .sheet(isPresented: .constant(true)) {
            DeviceListSheetView(service: SimulatedDeviceConnectionService(discoveryDelay: .milliseconds(200)))
        }
}
