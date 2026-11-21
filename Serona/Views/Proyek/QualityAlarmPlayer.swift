//
//  QualityAlarmPlayer.swift
//  Serona
//
//  Created by Steffany Florence on 21/11/26.
//

import AudioToolbox
import AVFoundation
import Foundation

// Plays a repeating alarm tone while `QualityAlertSheetView` is visible.
@MainActor
final class QualityAlarmPlayer {
    static let shared = QualityAlarmPlayer()

    private var audioPlayer: AVAudioPlayer?
    private(set) var isPlaying = false

    private init() {}

    func start() {
        // Avoid playing audio inside Xcode Canvas previews.
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            return
        }
        guard !isPlaying else { return }
        isPlaying = true

        configureAudioSession()

        do {
            let player: AVAudioPlayer
            if let bundledURL = Self.bundledAlarmURL() {
                player = try AVAudioPlayer(contentsOf: bundledURL)
            } else {
                player = try AVAudioPlayer(data: Self.makeFallbackAlarmWAVData())
            }
            player.numberOfLoops = -1
            player.volume = 1.0
            player.prepareToPlay()
            player.play()
            audioPlayer = player
        } catch {
            // Fallback to standard system alert sound if AVAudioPlayer cannot initialize.
            AudioServicesPlayAlertSound(1005)
        }
    }

    func stop() {
        guard isPlaying else { return }
        isPlaying = false

        audioPlayer?.stop()
        audioPlayer = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.duckOthers])
        try? session.setActive(true)
    }

    private static func bundledAlarmURL() -> URL? {
        for ext in ["wav", "mp3", "caf", "m4a"] {
            if let url = Bundle.main.url(forResource: "alarm", withExtension: ext) {
                return url
            }
        }
        return nil
    }

    // Generates a 1.25-second two-tone alarm pulse (16-bit mono PCM WAV) so no external audio file is required.
    private static func makeFallbackAlarmWAVData() -> Data {
        let sampleRate = 44_100
        let totalDuration = 1.25
        let numSamples = Int(Double(sampleRate) * totalDuration)
        let bytesPerSample = 2
        let dataSize = numSamples * bytesPerSample

        var data = Data(capacity: 44 + dataSize)

        func appendUInt32(_ value: UInt32) {
            var le = value.littleEndian
            withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
        }

        func appendUInt16(_ value: UInt16) {
            var le = value.littleEndian
            withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
        }

        // RIFF / WAVE header
        data.append(contentsOf: "RIFF".utf8)
        appendUInt32(UInt32(36 + dataSize))
        data.append(contentsOf: "WAVE".utf8)
        data.append(contentsOf: "fmt ".utf8)
        appendUInt32(16)
        appendUInt16(1) // PCM
        appendUInt16(1) // Mono
        appendUInt32(UInt32(sampleRate))
        appendUInt32(UInt32(sampleRate * bytesPerSample))
        appendUInt16(UInt16(bytesPerSample))
        appendUInt16(16)
        data.append(contentsOf: "data".utf8)
        appendUInt32(UInt32(dataSize))

        // Three short alert pulses (A5 -> D6 -> D6) followed by a brief pause
        let pulses: [(start: Double, end: Double, freq: Double)] = [
            (0.00, 0.16, 880.00),
            (0.24, 0.40, 1174.66),
            (0.48, 0.64, 1174.66),
        ]

        let fadeDuration = 0.012
        let amplitude = 0.85

        for i in 0 ..< numSamples {
            let t = Double(i) / Double(sampleRate)
            var sampleValue = 0.0

            for pulse in pulses where t >= pulse.start && t <= pulse.end {
                let localT = t - pulse.start
                let remaining = pulse.end - t
                let fadeIn = min(1.0, localT / fadeDuration)
                let fadeOut = min(1.0, remaining / fadeDuration)
                let envelope = min(fadeIn, fadeOut)
                sampleValue = sin(2.0 * .pi * pulse.freq * t) * amplitude * envelope
                break
            }

            let intSample = Int16(max(-1.0, min(1.0, sampleValue)) * Double(Int16.max))
            var leSample = intSample.littleEndian
            withUnsafeBytes(of: &leSample) { data.append(contentsOf: $0) }
        }

        return data
    }
}
