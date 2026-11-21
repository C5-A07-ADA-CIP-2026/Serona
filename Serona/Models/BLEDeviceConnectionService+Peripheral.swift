import CoreBluetooth
import Foundation

extension BLEDeviceConnectionService: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: (any Error)?) {
        let session = sessionForDelegate(peripheral)
        if let error {
            failReadiness(session, with: error)
            return
        }
        guard let service = peripheral.services?.first(where: { $0.uuid == Self.serviceUUID }) else {
            failReadiness(session, with: Self.sensorNotFoundError)
            return
        }
        peripheral.discoverCharacteristics([Self.measurementCharacteristicUUID], for: service)
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: (any Error)?
    ) {
        let session = sessionForDelegate(peripheral)
        if let error {
            failReadiness(session, with: error)
            return
        }
        guard service.uuid == Self.serviceUUID,
              let characteristic = service.characteristics?.first(where: {
                  $0.uuid == Self.measurementCharacteristicUUID
              })
        else {
            failReadiness(session, with: Self.sensorNotFoundError)
            return
        }
        session.characteristic = characteristic
        peripheral.setNotifyValue(true, for: characteristic)
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: (any Error)?
    ) {
        let session = sessionForDelegate(peripheral)
        if let error {
            failReadiness(session, with: error)
            return
        }
        guard characteristic.uuid == Self.measurementCharacteristicUUID,
              characteristic.isNotifying
        else {
            failReadiness(session, with: Self.sensorNotFoundError)
            return
        }
        session.state = .ready
        session.readinessContinuation?.resume(returning: ())
        session.readinessContinuation = nil
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: (any Error)?
    ) {
        guard characteristic.uuid == Self.measurementCharacteristicUUID else { return }
        let session = sessionForDelegate(peripheral)

        if let error {
            completeInitialRead(in: session, with: .failure(error))
            return
        }
        guard let data = characteristic.value, !data.isEmpty else {
            completeInitialRead(in: session, with: .failure(MeasurementPayloadError.empty))
            return
        }
        do {
            let frames = try session.frameDecoder.append(data)
            for frame in frames {
                let measurement = try JSONDecoder().decode(ColorMeasurement.self, from: frame).validated()
                for continuation in session.subscribers.values {
                    continuation.yield(measurement)
                }
                completeInitialRead(in: session, with: .success(measurement))
            }
        } catch {
            completeInitialRead(in: session, with: .failure(error))
        }
    }

    private func sessionForDelegate(_ peripheral: CBPeripheral) -> PeripheralSession {
        if let existing = sessionForIdentifier(peripheral.identifier) {
            return existing
        }
        return createSessionForDelegate(peripheral)
    }

    private func failReadiness(_ session: PeripheralSession, with error: any Error) {
        session.state = .failed(error.localizedDescription)
        session.readinessContinuation?.resume(throwing: error)
        session.readinessContinuation = nil
    }

    private func completeInitialRead(
        in session: PeripheralSession,
        with result: Result<ColorMeasurement, any Error>
    ) {
        guard let continuation = session.readContinuation else { return }
        session.readContinuation = nil
        continuation.resume(with: result)
    }
}
