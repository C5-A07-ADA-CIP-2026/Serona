//
//  BLEDeviceConnectionService.swift
//  Serona
//
//  Created by Hana Azizah Nurhadi on 21/10/26.
//

import CoreBluetooth
import Foundation

final class BLEDeviceConnectionService: NSObject, DeviceConnectionService, @unchecked Sendable {
    /// Instance tunggal (singleton) agar CBCentralManager tidak terhapus selama siklus hidup aplikasi
    static let shared = BLEDeviceConnectionService()

    /// Service UUID khusus untuk perangkat Serona
    static let serviceUUID = CBUUID(string: "4FAFC201-1FB5-459E-8FCC-C5C9C331914B")
    static let measurementCharacteristicUUID = CBUUID(string: "BEA57604-1C34-45B5-927A-94943E992383")

    static let sensorNotFoundError = NSError(
        domain: "BLEService",
        code: 404,
        userInfo: [NSLocalizedDescriptionKey: "Characteristic sensor tidak ditemukan"]
    )

    private var centralManager: CBCentralManager?
    /// Peripherals seen during the latest scan, by identifier, so `connect(to:)` can find the one the user picked.
    private var scannedPeripherals: [UUID: CBPeripheral] = [:]
    /// The name last reported for each peripheral of the latest scan.
    private var reportedNames: [UUID: String] = [:]
    /// The peripheral the app is (or is becoming) connected to.
    var discoveredPeripheral: CBPeripheral?
    private var pendingPeripheral: CBPeripheral?
    var measurementCharacteristic: CBCharacteristic?

    private let discoveryTimeout: TimeInterval
    private let connectionTimeout: TimeInterval

    // Continuation untuk jembatan async/await ke callback delegate CoreBluetooth
    private var scanContinuation: AsyncThrowingStream<DiscoveredDevice, any Error>.Continuation?
    private var activeScan: UUID?
    private var connectionAttempt: UUID?
    private var connectionContinuation: CheckedContinuation<Void, any Error>?
    var characteristicContinuation: CheckedContinuation<Void, any Error>?
    var measurementContinuation: CheckedContinuation<ColorMeasurement, any Error>?
//    var measurementStreamContinuation: AsyncStream<ColorMeasurement>.Continuation?
    /// Every project card streams the same device, so a reading goes to all open streams.
    let measurementBroadcaster = MeasurementBroadcaster()

    init(
        discoveryTimeout: TimeInterval = 10,
        connectionTimeout: TimeInterval = 10
    ) {
        self.discoveryTimeout = discoveryTimeout
        self.connectionTimeout = connectionTimeout
        super.init()
    }

    private func obtainCentralManager() -> CBCentralManager {
        if let centralManager {
            return centralManager
        }
        let manager = CBCentralManager(delegate: self, queue: .main)
        centralManager = manager
        return manager
    }
    
    private func finishPendingOperations(with error: any Error) {
        if let continuation = characteristicContinuation {
            characteristicContinuation = nil
            continuation.resume(throwing: error)
        }

        if let continuation = measurementContinuation {
            measurementContinuation = nil
            continuation.resume(throwing: error)
        }

//        measurementStreamContinuation?.finish()
//        measurementStreamContinuation = nil
        
        measurementBroadcaster.finishAll()
    }

    // MARK: - DeviceConnectionService Conformance

    func scanDevices() -> AsyncThrowingStream<DiscoveredDevice, any Error> {
        AsyncThrowingStream { continuation in
            finishScan(throwing: nil)
            let scan = UUID()
            activeScan = scan
            scanContinuation = continuation
            scannedPeripherals = [:]
            reportedNames = [:]
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in
                    guard let self, self.activeScan == scan else { return }
                    self.finishScan(throwing: nil)
                }
            }

            print("[BLE] 🔍 Memulai pencarian perangkat Serona (Service UUID: \(Self.serviceUUID.uuidString))...")
            let manager = obtainCentralManager()
            if manager.state == .poweredOn {
                startScanning(manager: manager)
            } else {
                print("[BLE] ⏳ Menunggu Bluetooth siap (status saat ini: \(manager.state.rawValue))...")
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + self.discoveryTimeout) { [weak self] in
                guard let self, activeScan == scan else { return }
                print("[BLE] ⏱️ Pencarian selesai (\(Int(discoveryTimeout)) detik).")
                finishScan(throwing: nil)
            }
        }
    }

    /// Ends the running scan, if any. `error` is delivered to whoever is iterating the stream.
    private func finishScan(throwing error: (any Error)?) {
        guard let continuation = scanContinuation else { return }
        centralManager?.stopScan()
        scanContinuation = nil
        activeScan = nil
        continuation.finish(throwing: error)
    }

    func connect(to device: DiscoveredDevice) async throws {
        guard let peripheral = scannedPeripherals[device.id] else {
            let errorUserInfo = [NSLocalizedDescriptionKey: "Perangkat belum ditemukan"]
            print("[BLE] ❌ Gagal menghubungkan: '\(device.nama)' tidak ada di hasil pencarian.")
            throw NSError(domain: "BLEService", code: 404, userInfo: errorUserInfo)
        }

        if peripheral.state == .connected {
            print("[BLE] ℹ️ Perangkat '\(device.nama)' sudah dalam keadaan terhubung.")
            select(peripheral)
            return
        }

        print("[BLE] ⏳ Menghubungkan ke '\(device.nama)' [\(peripheral.identifier.uuidString)]...")

        let attempt = UUID()
        connectionAttempt = attempt
        pendingPeripheral = peripheral
        try await withTaskCancellationHandler {
            try await performConnection(attempt: attempt)
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.abandonConnection(attempt: attempt)
            }
        }
        select(peripheral)
    }

    func disconnect(from device: DiscoveredDevice) async {
        guard let peripheral = scannedPeripherals[device.id] else {
            return
        }

        print("[BLE] 🔌 Memutus koneksi dari '\(device.nama)'...")

        if peripheral === discoveredPeripheral {
            let error = NSError(
                domain: "BLEService",
                code: 410,
                userInfo: [
                    NSLocalizedDescriptionKey: "Perangkat terputus"
                ]
            )

            finishPendingOperations(with: error)

            discoveredPeripheral = nil
            measurementCharacteristic = nil
        }

        centralManager?.cancelPeripheralConnection(peripheral)
    }

    /// Connects to `pendingPeripheral` and resumes when CoreBluetooth reports the result, or after the timeout.
    private func performConnection(attempt: UUID) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            guard let peripheral = pendingPeripheral else {
                continuation.resume(throwing: CancellationError())
                return
            }
            connectionContinuation?.resume(throwing: CancellationError())
            connectionContinuation = continuation
            obtainCentralManager().connect(peripheral, options: nil)

            DispatchQueue.main.asyncAfter(deadline: .now() + connectionTimeout) { [weak self] in
                guard let self, connectionAttempt == attempt, let cont = connectionContinuation else { return }
                print("[BLE] ⏱️ Waktu koneksi habis. Membatalkan koneksi...")
                if let peripheral = pendingPeripheral {
                    centralManager?.cancelPeripheralConnection(peripheral)
                }
                pendingPeripheral = nil
                connectionContinuation = nil
                let timeoutError = NSError(
                    domain: "BLEService",
                    code: 408,
                    userInfo: [NSLocalizedDescriptionKey: "Waktu koneksi habis"]
                )
                cont.resume(throwing: timeoutError)
            }
        }
    }

    /// Makes `peripheral` the one the app reads from, dropping the previously selected one.
    private func select(_ peripheral: CBPeripheral) {
        if let previous = discoveredPeripheral,
           previous !== peripheral {
            centralManager?.cancelPeripheralConnection(previous)
        }

        discoveredPeripheral = peripheral
        peripheral.delegate = self

        measurementCharacteristic = nil
        pendingPeripheral = nil
    }

    private func abandonConnection(attempt: UUID) {
        guard connectionAttempt == attempt, let continuation = connectionContinuation else { return }
        print("[BLE] 🛑 Koneksi dibatalkan oleh pengguna.")
        connectionContinuation = nil
        if let peripheral = pendingPeripheral {
            centralManager?.cancelPeripheralConnection(peripheral)
        }
        pendingPeripheral = nil
        continuation.resume(throwing: CancellationError())
    }

    func readInitialColorMeasurement() async throws -> ColorMeasurement {
        guard let peripheral = discoveredPeripheral, peripheral.state == .connected else {
            throw NSError(
                domain: "BLEService",
                code: 409,
                userInfo: [NSLocalizedDescriptionKey: "Perangkat belum terhubung"]
            )
        }

        try await obtainMeasurementCharacteristic(from: peripheral)
        guard let characteristic = measurementCharacteristic else {
            throw Self.sensorNotFoundError
        }
        return try await withCheckedThrowingContinuation { continuation in
            measurementContinuation?.resume(throwing: CancellationError())
            measurementContinuation = continuation
            print("[BLE] 📥 Meminta pembacaan characteristic \(Self.measurementCharacteristicUUID.uuidString)...")
            peripheral.readValue(for: characteristic)
        }
    }

    func measurementUpdates() -> AsyncStream<ColorMeasurement> {
        measurementBroadcaster.stream()
    }
    
//    func measurementUpdates() -> AsyncStream<ColorMeasurement> {
//        AsyncStream { continuation in
//
//            // Aplikasi menggunakan satu subscriber untuk pembacaan sensor.
//            measurementStreamContinuation?.finish()
//
//            measurementStreamContinuation = continuation
//
//            continuation.onTermination = { [weak self] _ in
//                DispatchQueue.main.async {
//                    guard let self,
//                          self.measurementStreamContinuation != nil
//                    else {
//                        return
//                    }
//
//                    self.measurementStreamContinuation = nil
//                }
//            }
//        }
//    }

    private func obtainMeasurementCharacteristic(
        from peripheral: CBPeripheral
    ) async throws {
        if let measurementCharacteristic {
            _ = measurementCharacteristic
            return
        }

        try await withCheckedThrowingContinuation { continuation in
            characteristicContinuation?.resume(throwing: CancellationError())
            characteristicContinuation = continuation
            peripheral.discoverServices([Self.serviceUUID])
        }
    }

    private func startScanning(manager: CBCentralManager) {
        print("[BLE] 📡 Sedang memindai sinyal advertising BLE...")
        manager.scanForPeripherals(
            withServices: [Self.serviceUUID],
            // Duplicates are needed so the scan response (which holds the name) is delivered too.
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
        // The ESP32 stops advertising while connected, so a device this app is still connected to
        // (e.g. the user left the form without saving) is only found this way.
        for peripheral in manager.retrieveConnectedPeripherals(withServices: [Self.serviceUUID]) {
            report(peripheral, advertisedName: nil)
        }
    }

    /// Remembers `peripheral` and yields it to the running scan, again only when a real name replaces "Tanpa Nama".
    private func report(_ peripheral: CBPeripheral, advertisedName: String?) {
        // The ESP32 sends its name in the scan response, which can arrive after the first callback for the device.
        let resolvedName = DiscoveredDevice.resolveName(
            peripheralName: peripheral.name,
            advertisedName: advertisedName
        )
        let name = resolvedName ?? DiscoveredDevice.unnamed
        guard reportedNames[peripheral.identifier] != name else { return }
        if reportedNames[peripheral.identifier] != nil, resolvedName == nil {
            return
        }
        print("[BLE] ✨ Ditemukan: '\(name)' | UUID: \(peripheral.identifier.uuidString)")

        reportedNames[peripheral.identifier] = name
        scannedPeripherals[peripheral.identifier] = peripheral
        peripheral.delegate = self
        scanContinuation?.yield(DiscoveredDevice(id: peripheral.identifier, nama: name))
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEDeviceConnectionService: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("[BLE] 🟢 Bluetooth aktif dan siap digunakan.")
            if scanContinuation != nil {
                startScanning(manager: central)
            }
        case .poweredOff:
            print("[BLE] 🔴 Bluetooth tidak aktif! Harap nyalakan Bluetooth di Pengaturan.")
            let error = NSError(
                domain: "BLEService",
                code: central.state.rawValue,
                userInfo: [NSLocalizedDescriptionKey: "Bluetooth tidak aktif"]
            )
            finishScan(throwing: error)
        case .unauthorized:
            print("[BLE] ⚠️ Izin akses Bluetooth ditolak.")
            let error = NSError(
                domain: "BLEService",
                code: central.state.rawValue,
                userInfo: [NSLocalizedDescriptionKey: "Izin Bluetooth ditolak"]
            )
            finishScan(throwing: error)
        case .unsupported:
            print("[BLE] ⚠️ Perangkat tidak mendukung Bluetooth Low Energy.")
            let error = NSError(
                domain: "BLEService",
                code: central.state.rawValue,
                userInfo: [NSLocalizedDescriptionKey: "Perangkat tidak mendukung Bluetooth"]
            )
            finishScan(throwing: error)
        default:
            print("[BLE] ℹ️ Status Bluetooth berubah ke: \(central.state.rawValue)")
        }
    }

    func centralManager(
        _: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi _: NSNumber
    ) {
        report(peripheral, advertisedName: advertisementData[CBAdvertisementDataLocalNameKey] as? String)
    }

    func centralManager(
        _: CBCentralManager,
        didConnect peripheral: CBPeripheral
    ) {
        guard peripheral === pendingPeripheral else {
            centralManager?.cancelPeripheralConnection(peripheral)
            return
        }

        print("[BLE] ✅ Sukses tersambung ke '\(peripheral.name ?? "ESP32")'!")

        peripheral.delegate = self

        connectionContinuation?.resume(returning: ())
        connectionContinuation = nil
    }

    func centralManager(_: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: (any Error)?) {
        let name = peripheral.name ?? "ESP32"
        let defaultError = NSError(
            domain: "BLEService",
            code: 500,
            userInfo: [NSLocalizedDescriptionKey: "Gagal terhubung"]
        )
        let err = error ?? defaultError
        print("[BLE] ❌ Gagal menyambung ke '\(name)': \(err.localizedDescription)")
        connectionContinuation?.resume(throwing: err)
        connectionContinuation = nil
    }

    func centralManager(
        _: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: (any Error)?
    ) {
        let name = peripheral.name ?? "ESP32"

        print("[BLE] 🔌 Perangkat '\(name)' terputus.")

        if let error {
            print("[BLE] ⚠️ Alasan disconnect: \(error.localizedDescription)")
        }

        guard peripheral === discoveredPeripheral else {
            return
        }

        let disconnectError = NSError(
            domain: "BLEService",
            code: 410,
            userInfo: [
                NSLocalizedDescriptionKey: "Koneksi ke sensor terputus"
            ]
        )

        finishPendingOperations(with: disconnectError)

        discoveredPeripheral = nil
        measurementCharacteristic = nil
    }
}
