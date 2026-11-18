//
//  DeviceListViewModel.swift
//  Serona
//

import Foundation
import Observation

/// Drives the device list sheet: scan for devices, connect to one, cancel while connecting.
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
    /// Identifies the scan that owns `devices` and `isScanning`, so a superseded scan cannot touch them.
    private var activeScan: UUID?

    /// `connectedDevice` is the device that is already connected when the list opens, so it shows as connected.
    init(service: (any DeviceConnecting)? = nil, connectedDevice: DiscoveredDevice? = nil) {
        self.service = service ?? DeviceConnectionServices.default
        self.connectedDevice = connectedDevice
    }

    /// Starts a fresh scan (replacing a running one) and returns when it ends.
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
                // The same device can be reported again once its name is known.
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

    /// Connects to `device` and stops scanning. Ignored while another connection is in progress.
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
            // A connection the user cancelled is not a failure.
            if !task.isCancelled, !(error is CancellationError) {
                errorMessage = "Gagal menyambungkan \(device.nama): \(error.localizedDescription)"
            }
        }
        connectionTask = nil
        connectingDevice = nil
    }

    /// Drops the connection to the connected device. It stays in `devices`, so it can be connected again.
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
