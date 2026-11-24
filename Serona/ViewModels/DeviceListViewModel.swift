import Foundation
import Observation

@MainActor
@Observable
final class DeviceListViewModel {
    private(set) var devices: [DiscoveredDevice] = []
    private(set) var isScanning = false
    private(set) var connectingDevice: DiscoveredDevice?
    private(set) var connectedDevice: DiscoveredDevice?
    private(set) var errorMessage: String?

    private let service: any DeviceConnecting
    private var scanTask: Task<Void, Never>?
    private var connectionTask: Task<Void, any Error>?

    private var activeScan: UUID?

    init(service: (any DeviceConnecting)? = nil, connectedDevice: DiscoveredDevice? = nil) {
        self.service = service ?? DeviceConnectionServices.default
        self.connectedDevice = connectedDevice
    }

    func scan() async {
        scanTask?.cancel()
        devices = []
        errorMessage = nil
        let scan = UUID()
        activeScan = scan
        isScanning = true
        let task = Task { await collectDevices(for: scan) }
        scanTask = task
        await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
    }

    private func collectDevices(for scan: UUID) async {
        defer {
            if activeScan == scan {
                activeScan = nil
                isScanning = false
            }
        }
        do {
            for try await device in service.scanDevices() {
                guard activeScan == scan else { return }

                if let index = devices.firstIndex(where: { $0.id == device.id }) {
                    devices[index] = device
                } else {
                    devices.append(device)
                }
            }
        } catch is CancellationError {
            return
        } catch {
            guard activeScan == scan else { return }
            errorMessage = "Gagal mencari perangkat: \(error.localizedDescription)"
        }
    }

    func connect(_ device: DiscoveredDevice) async {
        guard connectingDevice == nil else { return }
        scanTask?.cancel()
        connectingDevice = device
        errorMessage = nil
        let task = Task { try await service.connect(to: device) }
        connectionTask = task
        do {
            try await task.value
            connectedDevice = device
        } catch {
            if !task.isCancelled, !(error is CancellationError) {
                errorMessage = "Gagal menyambungkan \(device.nama): \(error.localizedDescription)"
            }
        }
        connectionTask = nil
        connectingDevice = nil
    }

    func disconnect() async {
        guard let device = connectedDevice else { return }
        await service.disconnect(from: device)
        connectedDevice = nil
    }

    func cancelConnecting() {
        connectionTask?.cancel()
    }

    func clearError() {
        errorMessage = nil
    }
}
