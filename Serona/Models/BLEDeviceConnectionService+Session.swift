import CoreBluetooth
import Foundation

extension BLEDeviceConnectionService {
    func prepare(_ session: PeripheralSession, reconnecting: Bool) async throws {
        if session.peripheral.state != .connected {
            try await connect(session, reconnecting: reconnecting)
        }
        if session.characteristic?.isNotifying != true {
            try await discoverAndSubscribe(session)
        }
        session.state = .ready
    }

    func connect(_ session: PeripheralSession, reconnecting: Bool) async throws {
        if session.peripheral.state == .connected {
            return
        }
        session.state = reconnecting ? .reconnecting : .connecting
        try await withCheckedThrowingContinuation { continuation in
            session.connectionContinuation?.resume(throwing: CancellationError())
            let attempt = UUID()
            session.connectionAttempt = attempt
            session.connectionContinuation = continuation
            obtainCentralManager().connect(session.peripheral, options: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + connectionTimeout) { [weak self, weak session] in
                guard let self, let session,
                      session.connectionAttempt == attempt,
                      let continuation = session.connectionContinuation
                else { return }
                session.connectionContinuation = nil
                centralManager?.cancelPeripheralConnection(session.peripheral)
                let error = timeoutError("Waktu koneksi habis")
                session.state = .failed(error.localizedDescription)
                continuation.resume(throwing: error)
            }
        }
    }

    func discoverAndSubscribe(_ session: PeripheralSession) async throws {
        session.state = .discovering
        try await withCheckedThrowingContinuation { continuation in
            session.readinessContinuation?.resume(throwing: CancellationError())
            let attempt = UUID()
            session.readinessAttempt = attempt
            session.readinessContinuation = continuation
            session.characteristic = nil
            session.peripheral.discoverServices([Self.serviceUUID])
            DispatchQueue.main.asyncAfter(deadline: .now() + connectionTimeout) { [weak self, weak session] in
                guard let self, let session,
                      session.readinessAttempt == attempt,
                      let continuation = session.readinessContinuation
                else { return }
                session.readinessContinuation = nil
                let error = timeoutError("Waktu penemuan sensor habis")
                session.state = .failed(error.localizedDescription)
                continuation.resume(throwing: error)
            }
        }
    }

    func timeoutError(_ message: String) -> NSError {
        NSError(domain: "BLEService", code: 408, userInfo: [NSLocalizedDescriptionKey: message])
    }

    func failPendingOperations(in session: PeripheralSession, with error: any Error) {
        session.connectionContinuation?.resume(throwing: error)
        session.connectionContinuation = nil
        session.readinessContinuation?.resume(throwing: error)
        session.readinessContinuation = nil
        session.readContinuation?.resume(throwing: error)
        session.readContinuation = nil
    }

    func finishSubscribers(in session: PeripheralSession) {
        for continuation in session.subscribers.values {
            continuation.finish()
        }
        session.subscribers.removeAll()
    }
}
