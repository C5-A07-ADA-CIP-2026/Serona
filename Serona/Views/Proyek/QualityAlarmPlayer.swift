//
//  QualityAlarmPlayer.swift
//  Serona
//
//  Created by Steffany Florence on 21/11/26.
//

import AudioToolbox
import AVFoundation
import Foundation

/// Plays a synthesized repeating alarm tone while `QualityAlertSheetView` is visible.
@MainActor
final class QualityAlarmPlayer {
    static let shared = QualityAlarmPlayer()

    private var audioPlayer: AVAudioPlayer?
    private(set) var isPlaying = false

    private init() {}

    func start() {
        guard !isPlaying else { return }
        isPlaying = true

        configureAudioSession()

        do {
            let player = try AVAudioPlayer(data: Self.makeAlarmWAVData())
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

    /// Generates a 1.0-second synthesized constant-pulse electronic buzzer alarm cycle (16-bit mono PCM WAV).
    private static func makeAlarmWAVData() -> Data {
        let sampleRate = 44100
        let bytesPerSample = 2
        // 1.0 second at 2.0 Hz produces exactly 2 identical pulses per buffer, looping seamlessly.
        let duration = 1.00
        let numSamples = Int(Double(sampleRate) * duration)
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

    private static func alarmSample(at time: Double) -> Double {
        let amplitude = 0.85

        // Constant 2.0 Hz pulse rate (1 pulse every 0.5 seconds, seamlessly looped)
        let pulseRate = 2.0
        let pulsePhase = (time * pulseRate).truncatingRemainder(dividingBy: 1.0)
        let pulseDuration = 1.0 / pulseRate
        let pulseTime = pulsePhase * pulseDuration

        // Smooth 8 ms attack/release on each pulse to avoid clicks
        let edgeFade = 0.008
        let dutyCycle = 0.60
        let activeTime = pulseDuration * dutyCycle
        guard pulseTime <= activeTime else { return 0 }

        let fadeIn = min(1.0, pulseTime / edgeFade)
        let fadeOut = min(1.0, (activeTime - pulseTime) / edgeFade)
        let envelope = min(fadeIn, fadeOut)

        // Metallic two-frequency buzzer carrier (880 Hz + 1108 Hz minor third + odd harmonics)
        let baseFrequency = 880.0
        let thirdFrequency = 1108.73
        let angle1 = 2.0 * .pi * baseFrequency * time
        let angle2 = 2.0 * .pi * thirdFrequency * time

        let buzzerWave = sin(angle1)
            + 0.65 * sin(angle2)
            + 0.45 * sin(3.0 * angle1)
            + 0.30 * sin(3.0 * angle2)
            + 0.20 * sin(5.0 * angle1)

        return (buzzerWave / 2.60) * amplitude * envelope
    }
}
