//
//  QualityAlarmPlayer.swift
//  Serona
//
//  Created by Steffany Florence on 21/11/26.
//

import AudioToolbox
import AVFoundation
import Foundation

/// Plays a repeating alarm tone while `QualityAlertSheetView` is visible.
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
            let player: AVAudioPlayer = if let bundledURL = Self.bundledAlarmURL() {
                try AVAudioPlayer(contentsOf: bundledURL)
            } else {
                try AVAudioPlayer(data: Self.makeFallbackAlarmWAVData())
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

    /// Generates a 1.25-second two-tone alarm pulse (16-bit mono PCM WAV) so no external audio file is required.
    private static func makeFallbackAlarmWAVData() -> Data {
        let sampleRate = 44100
        let bytesPerSample = 2
        let numSamples = Int(Double(sampleRate) * 1.25)
        let dataSize = numSamples * bytesPerSample

        var data = Data(capacity: 44 + dataSize)
        appendWAVHeader(to: &data, sampleRate: sampleRate, bytesPerSample: bytesPerSample, dataSize: dataSize)

        for index in 0 ..< numSamples {
            let time = Double(index) / Double(sampleRate)
            let intSample = Int16(max(-1.0, min(1.0, alarmSample(at: time))) * Double(Int16.max))
            append(intSample.littleEndian, to: &data)
        }

        return data
    }

    private static func append(_ value: some FixedWidthInteger, to data: inout Data) {
        withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
    }

    private static func appendWAVHeader(to data: inout Data, sampleRate: Int, bytesPerSample: Int, dataSize: Int) {
        data.append(contentsOf: "RIFF".utf8)
        append(UInt32(36 + dataSize), to: &data)
        data.append(contentsOf: "WAVE".utf8)
        data.append(contentsOf: "fmt ".utf8)
        append(UInt32(16), to: &data)
        append(UInt16(1), to: &data) // PCM
        append(UInt16(1), to: &data) // Mono
        append(UInt32(sampleRate), to: &data)
        append(UInt32(sampleRate * bytesPerSample), to: &data)
        append(UInt16(bytesPerSample), to: &data)
        append(UInt16(16), to: &data)
        data.append(contentsOf: "data".utf8)
        append(UInt32(dataSize), to: &data)
    }

    private struct AlarmPulse {
        let start: Double
        let end: Double
        let frequency: Double
    }

    /// Three short alert pulses (A5 -> D6 -> D6) followed by a brief pause.
    private static let alarmPulses = [
        AlarmPulse(start: 0.00, end: 0.16, frequency: 880.00),
        AlarmPulse(start: 0.24, end: 0.40, frequency: 1174.66),
        AlarmPulse(start: 0.48, end: 0.64, frequency: 1174.66),
    ]

    private static func alarmSample(at time: Double) -> Double {
        let fadeDuration = 0.012
        let amplitude = 0.85
        guard let pulse = alarmPulses.first(where: { time >= $0.start && time <= $0.end }) else { return 0 }
        let fadeIn = min(1.0, (time - pulse.start) / fadeDuration)
        let fadeOut = min(1.0, (pulse.end - time) / fadeDuration)
        return sin(2.0 * .pi * pulse.frequency * time) * amplitude * min(fadeIn, fadeOut)
    }
}
