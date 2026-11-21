import CoreBluetooth
import Foundation

final class BLEDeviceConnectionService: NSObject, DeviceConnectionService, @unchecked Sendable {
    static let shared = BLEDeviceConnectionService()

    static let serviceUUID = CBUUID(string: "4FAFC201-1FB5-459E-8FCC-C5C9C331914B")
    static let measurementCharacteristicUUID = CBUUID(string: "BEA57604-1C34-45B5-927A-94943E992383")

    static let sensorNotFoundError = NSError(
        domain: "BLEService",
        code: 404,
        userInfo: [NSLocalizedDescriptionKey: "Characteristic sensor tidak ditemukan"]
    )

    final class PeripheralSession {
        let peripheral: CBPeripheral
        var state: DeviceConnectionState = .disconnected
        var characteristic: CBCharacteristic?
        var connectionContinuation: CheckedContinuation<Void, any Error>?
        var readinessContinuation: CheckedContinuation<Void, any Error>?
        var readContinuation: CheckedContinuation<ColorMeasurement, any Error>?
        var subscribers: [UUID: AsyncStream<ColorMeasurement>.Continuation] = [:]
        var frameDecoder = MeasurementFrameDecoder()
        var connectionAttempt = UUID()
        var readinessAttempt = UUID()
        var readAttempt = UUID()

        init(peripheral: CBPeripheral) {
            self.peripheral = peripheral
        }
    }

    var centralManager: CBCentralManager?
    private var scannedPeripherals: [UUID: CBPeripheral] = [:]
    private var reportedNames: [UUID: String] = [:]
    private var sessions: [UUID: PeripheralSession] = [:]

    private let discoveryTimeout: TimeInterval
    let connectionTimeout: TimeInterval
    private let measurementTimeout: TimeInterval

    private var scanContinuation: AsyncThrowingStream<DiscoveredDevice, any Error>.Continuation?
    private var activeScan: UUID?

    init(
        discoveryTimeout: TimeInterval = 10,
        connectionTimeout: TimeInterval = 10,
        measurementTimeout: TimeInterval = 5
    ) {
        self.discoveryTimeout = discoveryTimeout
        self.connectionTimeout = connectionTimeout
        self.measurementTimeout = measurementTimeout
        super.init()
    }

    func measurementSource(for deviceID: UUID) -> any ColorMeasurementSource {
        BLEMeasurementSource(deviceID: deviceID, service: self)
    }

    func scanDevices() -> AsyncThrowingStream<DiscoveredDevice, any Error> {
        AsyncThrowingStream { continuation in
            finishScan(throwing: nil)
            let scan = UUID()
            activeScan = scan
            scanContinuation = continuation
            reportedNames = [:]
            continuation.onTermination = { [weak self] _ in
                DispatchQueue.main.async {
                    guard let self, self.activeScan == scan else { return }
                    self.finishScan(throwing: nil)
                }
            }

            let manager = obtainCentralManager()
            if manager.state == .poweredOn {
                startScanning(manager: manager)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + discoveryTimeout) { [weak self] in
                guard let self, activeScan == scan else { return }
                finishScan(throwing: nil)
            }
        }
    }

    func connect(to device: DiscoveredDevice) async throws {
        let peripheral = try peripheral(for: device.id)
        let session = session(for: peripheral)
        try await prepare(session, reconnecting: false)
    }

    func disconnect(from device: DiscoveredDevice) async {
        guard let session = sessions[device.id] else { return }
        centralManager?.cancelPeripheralConnection(session.peripheral)
        failPendingOperations(in: session, with: CancellationError())
        finishSubscribers(in: session)
        session.characteristic = nil
        session.state = .disconnected
    }

    func state(for deviceID: UUID) -> DeviceConnectionState {
        sessions[deviceID]?.state ?? .disconnected
    }

    func readMeasurement(from deviceID: UUID) async throws -> ColorMeasurement {
        let session = try restoredSession(for: deviceID)
        try await prepare(session, reconnecting: session.peripheral.state != .connected)

        guard let characteristic = session.characteristic else {
            throw Self.sensorNotFoundError
        }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                session.readContinuation?.resume(throwing: CancellationError())
                let attempt = UUID()
                session.readAttempt = attempt
                session.readContinuation = continuation
                session.peripheral.readValue(for: characteristic)
                DispatchQueue.main.asyncAfter(deadline: .now() + measurementTimeout) { [weak self, weak session] in
                    guard let self, let session,
                          session.readAttempt == attempt,
                          let continuation = session.readContinuation
                    else { return }
                    session.readContinuation = nil
                    continuation.resume(throwing: timeoutError("Waktu pembacaan sensor habis"))
                }
            }
        } onCancel: {
            DispatchQueue.main.async { [weak session] in
                guard let session, let continuation = session.readContinuation else { return }
                session.readContinuation = nil
                continuation.resume(throwing: CancellationError())
            }
        }
    }

    func updates(from deviceID: UUID) -> AsyncStream<ColorMeasurement> {
        AsyncStream { continuation in
            let subscriberID = UUID()
            continuation.onTermination = { [weak self] _ in
                DispatchQueue.main.async {
                    self?.sessions[deviceID]?.subscribers.removeValue(forKey: subscriberID)
                }
            }

            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }
                do {
                    let session = try restoredSession(for: deviceID)
                    session.subscribers[subscriberID] = continuation
                    Task {
                        do {
                            try await self.prepare(
                                session,
                                reconnecting: session.peripheral.state != .connected
                            )
                        } catch {
                            session.state = .failed(error.localizedDescription)
                        }
                    }
                } catch {
                    continuation.finish()
                }
            }
        }
    }

    private func restoredSession(for deviceID: UUID) throws -> PeripheralSession {
        if let session = sessions[deviceID] {
            return session
        }
        let peripheral = try peripheral(for: deviceID)
        return session(for: peripheral)
    }

    private func peripheral(for deviceID: UUID) throws -> CBPeripheral {
        if let peripheral = scannedPeripherals[deviceID] {
            return peripheral
        }
        let manager = obtainCentralManager()
        if let peripheral = manager.retrievePeripherals(withIdentifiers: [deviceID]).first {
            scannedPeripherals[deviceID] = peripheral
            return peripheral
        }
        throw NSError(
            domain: "BLEService",
            code: 404,
            userInfo: [NSLocalizedDescriptionKey: "Perangkat perlu dipilih kembali"]
        )
    }

    private func session(for peripheral: CBPeripheral) -> PeripheralSession {
        if let existing = sessions[peripheral.identifier] {
            return existing
        }
        peripheral.delegate = self
        let session = PeripheralSession(peripheral: peripheral)
        sessions[peripheral.identifier] = session
        return session
    }

    func sessionForIdentifier(_ identifier: UUID) -> PeripheralSession? {
        sessions[identifier]
    }

    func createSessionForDelegate(_ peripheral: CBPeripheral) -> PeripheralSession {
        session(for: peripheral)
    }

    func obtainCentralManager() -> CBCentralManager {
        if let centralManager {
            return centralManager
        }
        let manager = CBCentralManager(delegate: self, queue: .main)
        centralManager = manager
        return manager
    }

    private func finishScan(throwing error: (any Error)?) {
        guard let continuation = scanContinuation else { return }
        centralManager?.stopScan()
        scanContinuation = nil
        activeScan = nil
        continuation.finish(throwing: error)
    }

    private func startScanning(manager: CBCentralManager) {
        manager.scanForPeripherals(
            withServices: [Self.serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
        for peripheral in manager.retrieveConnectedPeripherals(withServices: [Self.serviceUUID]) {
            report(peripheral, advertisedName: nil)
        }
    }

    private func report(_ peripheral: CBPeripheral, advertisedName: String?) {
        let resolvedName = DiscoveredDevice.resolveName(
            peripheralName: peripheral.name,
            advertisedName: advertisedName
        )
        let name = resolvedName ?? DiscoveredDevice.unnamed
        guard reportedNames[peripheral.identifier] != name else { return }
        if reportedNames[peripheral.identifier] != nil, resolvedName == nil {
            return
        }

        reportedNames[peripheral.identifier] = name
        scannedPeripherals[peripheral.identifier] = peripheral
        peripheral.delegate = self
        scanContinuation?.yield(DiscoveredDevice(id: peripheral.identifier, nama: name))
    }
}

private struct BLEMeasurementSource: ColorMeasurementSource, @unchecked Sendable {
    let deviceID: UUID
    weak var service: BLEDeviceConnectionService?

    var connectionState: DeviceConnectionState {
        service?.state(for: deviceID) ?? .disconnected
    }

    func readInitialColorMeasurement() async throws -> ColorMeasurement {
        guard let service else { throw CancellationError() }
        return try await service.readMeasurement(from: deviceID)
    }

    func measurementUpdates() -> AsyncStream<ColorMeasurement> {
        service?.updates(from: deviceID) ?? AsyncStream { $0.finish() }
    }
}

extension BLEDeviceConnectionService: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            if scanContinuation != nil {
                startScanning(manager: central)
            }
        case .poweredOff, .unauthorized, .unsupported:
            let error = NSError(
                domain: "BLEService",
                code: central.state.rawValue,
                userInfo: [NSLocalizedDescriptionKey: "Bluetooth tidak tersedia"]
            )
            finishScan(throwing: error)
            for session in sessions.values {
                session.state = .failed(error.localizedDescription)
                failPendingOperations(in: session, with: error)
                finishSubscribers(in: session)
            }
        default:
            break
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

    func centralManager(_: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let session = session(for: peripheral)
        session.connectionContinuation?.resume(returning: ())
        session.connectionContinuation = nil
    }

    func centralManager(_: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: (any Error)?) {
        let session = session(for: peripheral)
        let resolved = error ?? NSError(
            domain: "BLEService",
            code: 500,
            userInfo: [NSLocalizedDescriptionKey: "Gagal terhubung"]
        )
        session.state = .failed(resolved.localizedDescription)
        session.connectionContinuation?.resume(throwing: resolved)
        session.connectionContinuation = nil
    }

    func centralManager(
        _: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: (any Error)?
    ) {
        let session = session(for: peripheral)
        session.characteristic = nil
        let resolved = error ?? NSError(
            domain: "BLEService",
            code: 499,
            userInfo: [NSLocalizedDescriptionKey: "Koneksi perangkat terputus"]
        )
        session.state = .disconnected
        failPendingOperations(in: session, with: resolved)

        guard !session.subscribers.isEmpty else { return }
        session.state = .reconnecting
        Task {
            do {
                try await prepare(session, reconnecting: true)
            } catch {
                session.state = .failed(error.localizedDescription)
                finishSubscribers(in: session)
            }
        }
    }
}
