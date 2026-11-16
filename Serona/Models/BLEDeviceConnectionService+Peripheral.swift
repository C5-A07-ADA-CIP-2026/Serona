
//
//  BLEDeviceConnectionService+Peripheral.swift
//  Serona
//

import CoreBluetooth
import Foundation

// MARK: - CBPeripheralDelegate

extension BLEDeviceConnectionService: CBPeripheralDelegate {

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverServices error: (any Error)?
    ) {
        guard peripheral === discoveredPeripheral else { return }

        if let error {
            finishCharacteristicRequest(with: error)
            return
        }

        guard let services = peripheral.services,
              let service = services.first(where: { $0.uuid == Self.serviceUUID })
        else {
            finishCharacteristicRequest(with: Self.sensorNotFoundError)
            return
        }

        peripheral.discoverCharacteristics(
            [Self.measurementCharacteristicUUID],
            for: service
        )
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: (any Error)?
    ) {
        guard peripheral === discoveredPeripheral,
              service.uuid == Self.serviceUUID
        else {
            return
        }

        if let error {
            finishCharacteristicRequest(with: error)
            return
        }

        guard let characteristic = service.characteristics?.first(
            where: { $0.uuid == Self.measurementCharacteristicUUID }
        ) else {
            finishCharacteristicRequest(with: Self.sensorNotFoundError)
            return
        }

        measurementCharacteristic = characteristic

        peripheral.setNotifyValue(true, for: characteristic)

        finishCharacteristicRequest(with: nil)
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: (any Error)?
    ) {
        guard peripheral === discoveredPeripheral,
              characteristic.uuid == Self.measurementCharacteristicUUID
        else {
            return
        }

        if let error {
            print("[BLE] ❌ Gagal mengaktifkan notification: \(error.localizedDescription)")
            return
        }

        print("[BLE] 🔔 Notification sensor: \(characteristic.isNotifying)")
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: (any Error)?
    ) {
        guard peripheral === discoveredPeripheral,
              characteristic.uuid == Self.measurementCharacteristicUUID
        else {
            return
        }

        if let error {
            measurementContinuation?.resume(throwing: error)
            measurementContinuation = nil
            return
        }

        guard let data = characteristic.value else {
            let error = NSError(
                domain: "BLEService",
                code: 204,
                userInfo: [
                    NSLocalizedDescriptionKey: "ESP32 mengirim payload kosong"
                ]
            )

            measurementContinuation?.resume(throwing: error)
            measurementContinuation = nil
            return
        }

        do {
            let measurement = try JSONDecoder().decode(
                ColorMeasurement.self,
                from: data
            )

            print(
                "[BLE] 🎨 visibleAverage=\(measurement.visibleAverage), " +
                "clear=\(measurement.clear), nir=\(measurement.nir)"
            )

//            measurementStreamContinuation?.yield(measurement)

            measurementBroadcaster.yield(measurement)
            
            measurementContinuation?.resume(returning: measurement)
            measurementContinuation = nil

        } catch {
            print("[BLE] ❌ Gagal decode JSON: \(error.localizedDescription)")

            measurementContinuation?.resume(throwing: error)
            measurementContinuation = nil
        }
    }

    func finishCharacteristicRequest(with error: (any Error)?) {
        guard let continuation = characteristicContinuation else { return }

        characteristicContinuation = nil

        if let error {
            continuation.resume(throwing: error)
        } else {
            continuation.resume()
        }
    }
}


////
////  BLEDeviceConnectionService+Peripheral.swift
////  Serona
////
//
//import CoreBluetooth
//import Foundation
//
//// MARK: - CBPeripheralDelegate
//
//extension BLEDeviceConnectionService: CBPeripheralDelegate {
//    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: (any Error)?) {
//        if let error {
//            print("[BLE] ❌ Gagal menemukan service: \(error.localizedDescription)")
//            characteristicContinuation?.resume(throwing: error)
//            characteristicContinuation = nil
//            return
//        }
//        guard let services = peripheral.services else { return }
//        for service in services {
//            print("[BLE] 📦 Ditemukan service: \(service.uuid.uuidString)")
//            peripheral.discoverCharacteristics(nil, for: service)
//        }
//    }
//
//    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: (any Error)?) {
//        if let error {
//            print("[BLE] ❌ Gagal menemukan characteristic: \(error.localizedDescription)")
//            characteristicContinuation?.resume(throwing: error)
//            characteristicContinuation = nil
//            return
//        }
//        guard let characteristics = service.characteristics else {
//            let error = Self.sensorNotFoundError
//            characteristicContinuation?.resume(throwing: error)
//            characteristicContinuation = nil
//            return
//        }
//        for characteristic in characteristics {
//            print("[BLE] 🔑 Ditemukan characteristic: \(characteristic.uuid.uuidString)")
//            guard characteristic.uuid == Self.measurementCharacteristicUUID else { continue }
//            measurementCharacteristic = characteristic
//            peripheral.setNotifyValue(true, for: characteristic)
//            characteristicContinuation?.resume(returning: ())
//            characteristicContinuation = nil
//        }
//        if measurementCharacteristic == nil {
//            let error = Self.sensorNotFoundError
//            characteristicContinuation?.resume(throwing: error)
//            characteristicContinuation = nil
//        }
//    }
//
////    func peripheral(
////        _: CBPeripheral,
////        didUpdateValueFor characteristic: CBCharacteristic,
////        error: (any Error)?
////    ) {
////        guard characteristic.uuid == Self.measurementCharacteristicUUID else { return }
////
////        if let error {
////            measurementContinuation?.resume(throwing: error)
////            measurementContinuation = nil
////            return
////        }
////
////        guard let data = characteristic.value else {
////            let error = NSError(
////                domain: "BLEService",
////                code: 204,
////                userInfo: [NSLocalizedDescriptionKey: "ESP32 mengirim payload kosong"]
////            )
////            measurementContinuation?.resume(throwing: error)
////            measurementContinuation = nil
////            return
////        }
////
////        let rawPayload = String(data: data, encoding: .utf8) ?? "<bukan UTF-8>"
////        let hexPayload = data.map { String(format: "%02X", $0) }.joined(separator: " ")
////        print("[BLE] 📦 Payload diterima: \(rawPayload)")
////        print("[BLE] 🔢 Bytes payload: \(hexPayload)")
////
////        do {
////            let measurement = try JSONDecoder().decode(ColorMeasurement.self, from: data)
////            print(
////                "[BLE] 🎨 AS7341 visibleAverage=\(measurement.visibleAverage), " +
////                    "clear=\(measurement.clear), nir=\(measurement.nir)"
////            )
////            measurementStreamContinuation?.yield(measurement)
////            measurementContinuation?.resume(returning: measurement)
////        } catch {
////            measurementContinuation?.resume(throwing: error)
////        }
////        measurementContinuation = nil
////    }
//    func peripheral(
//        _: CBPeripheral,
//        didUpdateValueFor characteristic: CBCharacteristic,
//        error: (any Error)?
//    ) {
//        guard characteristic.uuid == Self.measurementCharacteristicUUID else { return }
//
//        if let error {
//            print("[BLE] ❌ Error update value: \(error.localizedDescription)")
//            // Jangan resume continuation streaming di sini agar stream tidak putus
//            return
//        }
//
//        guard let data = characteristic.value else {
//            print("[BLE] ⚠️ ESP32 mengirim payload kosong")
//            return
//        }
//
//        let rawPayload = String(data: data, encoding: .utf8) ?? "<bukan UTF-8>"
//        let hexPayload = data.map { String(format: "%02X", $0) }.joined(separator: " ")
//        print("[BLE] 📦 Payload diterima: \(rawPayload)")
//        print("[BLE] 🔢 Bytes payload: \(hexPayload)")
//
//        do {
//            let measurement = try JSONDecoder().decode(ColorMeasurement.self, from: data)
//            print(
//                "[BLE] 🎨 AS7341 visibleAverage=\(measurement.visibleAverage), " +
//                    "clear=\(measurement.clear), nir=\(measurement.nir)"
//            )
//
//            // 🔥 KUNCI REAL-TIME: Kirim terus menerus ke AsyncStream
//            measurementBroadcaster.yield(measurement)
//
//            // Hapus atau pisahkan measurementContinuation jika ini dipakai untuk inisialisasi awal saja
//            if let continuation = measurementContinuation {
//                continuation.resume(returning: measurement)
//                measurementContinuation = nil
//            }
//
//        } catch {
//            print("[BLE] ❌ Gagal parsing JSON: \(error)")
//            if let continuation = measurementContinuation {
//                continuation.resume(throwing: error)
//                measurementContinuation = nil
//            }
//        }
//    }
//}
