import Foundation

/// Reassembles one or more JSON objects from BLE notification fragments.
struct MeasurementFrameDecoder: Sendable {
    private(set) var buffer = Data()
    private let maximumBufferSize = 4096

    mutating func append(_ data: Data) throws -> [Data] {
        buffer.append(data)
        guard buffer.count <= maximumBufferSize else {
            buffer.removeAll(keepingCapacity: true)
            throw MeasurementPayloadError.tooLarge
        }

        var frames: [Data] = []
        var scanner = JSONObjectScanner()
        var consumedThrough: Data.Index?

        for index in buffer.indices {
            if let start = scanner.consume(buffer[index], at: index) {
                let end = buffer.index(after: index)
                frames.append(buffer.subdata(in: start ..< end))
                consumedThrough = end
            }
        }

        if let consumedThrough {
            buffer.removeSubrange(buffer.startIndex ..< consumedThrough)
        } else if scanner.depth == 0, !buffer.isEmpty, !buffer.contains(0x7B) {
            buffer.removeAll(keepingCapacity: true)
            throw MeasurementPayloadError.invalidFraming
        }
        return frames
    }
}

/// Tracks braces outside JSON strings so a complete top-level object can be cut out of a byte stream.
private struct JSONObjectScanner {
    private(set) var depth = 0
    private var start: Data.Index?
    private var inString = false
    private var escaped = false

    /// Feeds one byte; returns the start index of a top-level object when `byte` closes it.
    mutating func consume(_ byte: UInt8, at index: Data.Index) -> Data.Index? {
        if inString {
            updateString(with: byte)
            return nil
        }
        switch byte {
        case 0x22:
            inString = true
        case 0x7B:
            if depth == 0 {
                start = index
            }
            depth += 1
        case 0x7D where depth > 0:
            depth -= 1
            if depth == 0 {
                return start
            }
        default:
            break
        }
        return nil
    }

    private mutating func updateString(with byte: UInt8) {
        if escaped {
            escaped = false
        } else if byte == 0x5C {
            escaped = true
        } else if byte == 0x22 {
            inString = false
        }
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
