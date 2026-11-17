import Foundation

/// Reassembles one or more JSON objects from BLE notification fragments.
struct MeasurementFrameDecoder: Sendable {
    private(set) var buffer = Data()
    private let maximumBufferSize = 4_096

    mutating func append(_ data: Data) throws -> [Data] {
        buffer.append(data)
        guard buffer.count <= maximumBufferSize else {
            buffer.removeAll(keepingCapacity: true)
            throw MeasurementPayloadError.tooLarge
        }

        var frames: [Data] = []
        var start: Data.Index?
        var depth = 0
        var inString = false
        var escaped = false
        var consumedThrough: Data.Index?

        for index in buffer.indices {
            let byte = buffer[index]
            if inString {
                if escaped {
                    escaped = false
                } else if byte == 0x5C {
                    escaped = true
                } else if byte == 0x22 {
                    inString = false
                }
                continue
            }

            if byte == 0x22 {
                inString = true
            } else if byte == 0x7B {
                if depth == 0 {
                    start = index
                }
                depth += 1
            } else if byte == 0x7D, depth > 0 {
                depth -= 1
                if depth == 0, let start {
                    frames.append(buffer.subdata(in: start ..< buffer.index(after: index)))
                    consumedThrough = buffer.index(after: index)
                }
            }
        }

        if let consumedThrough {
            buffer.removeSubrange(buffer.startIndex ..< consumedThrough)
        } else if depth == 0, !buffer.isEmpty, !buffer.contains(0x7B) {
            buffer.removeAll(keepingCapacity: true)
            throw MeasurementPayloadError.invalidFraming
        }
        return frames
    }
}

enum MeasurementPayloadError: LocalizedError, Equatable {
    case empty
    case invalidFraming
    case tooLarge
    case invalidChannels
    case invalidValue

    var errorDescription: String? {
        switch self {
        case .empty: "ESP32 mengirim payload kosong"
        case .invalidFraming: "Format payload BLE tidak valid"
        case .tooLarge: "Payload BLE terlalu besar"
        case .invalidChannels: "Jumlah channel sensor tidak valid"
        case .invalidValue: "Nilai sensor tidak valid"
        }
    }
}

extension ColorMeasurement {
    func validated() throws -> ColorMeasurement {
        guard visibleAverage.isFinite, waterPH?.isFinite != false else {
            throw MeasurementPayloadError.invalidValue
        }
        if let waterPH, !(0 ... 14).contains(waterPH) {
            throw MeasurementPayloadError.invalidValue
        }
        if let channels, channels.count != 8 {
            throw MeasurementPayloadError.invalidChannels
        }
        return self
    }
}
