//
//  PerbaikiLarutanViewModel.swift
//  Serona
//

import Foundation
import Observation

/// One step of the "Perbaiki Larutan" guide.
enum PerbaikiStep: Equatable {
    case air
    case phAir
    case kepekatan
}

/// Walks the user through the steps that bring the solution back above its limits, one at a time.
@MainActor
@Observable
final class PerbaikiLarutanViewModel {
    static let gramSodaAbu = 10
    static let gramPewarna = 10

    private(set) var issue: QualityIssue
    private(set) var steps: [PerbaikiStep]
    let proyek: Proyek?
    var jumlahAir = 7
    private(set) var isFinished = false
    /// The soda to add, known once the water step was confirmed with a pH before and after the water.
    private(set) var penambahanSoda: PenambahanSoda?
    private let pHSebelum: Double?
    private(set) var activeIndex = 0

    /// `pHSebelum` is the pH when the limit was crossed, before any water is added (pH1).
    init(issue: QualityIssue, proyek: Proyek? = nil, pHSebelum: Double? = nil) {
        self.issue = issue
        self.proyek = proyek
        self.pHSebelum = pHSebelum
        steps = Self.calculateSteps(for: issue, existingSteps: [])
    }

    /// Merges a newly detected issue and appends the steps it needs without losing the active progress.
    func updateIssue(_ newIssue: QualityIssue) {
        guard newIssue != issue else { return }
        let combined = issue.combining(with: newIssue)
        issue = combined
        steps = Self.calculateSteps(for: combined, existingSteps: steps)
    }

    private static func calculateSteps(for issue: QualityIssue, existingSteps: [PerbaikiStep]) -> [PerbaikiStep] {
        let canonicalOrder: [PerbaikiStep] = [.air, .phAir, .kepekatan]
        let requiredSteps: Set<PerbaikiStep> = switch issue {
        case .kepekatan: [.air, .kepekatan]
        case .phAir: [.air, .phAir]
        case .keduanya: [.air, .phAir, .kepekatan]
        }

        var updated: [PerbaikiStep] = []
        for step in canonicalOrder {
            if existingSteps.contains(step) || requiredSteps.contains(step) {
                updated.append(step)
            }
        }
        return updated
    }

    var jumlahAirFormatted: String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "id_ID")
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: jumlahAir)) ?? "\(jumlahAir)"
    }

    func isActive(_ step: PerbaikiStep) -> Bool {
        !isFinished && activeIndex < steps.count && steps[activeIndex] == step
    }

    func isDone(_ step: PerbaikiStep) -> Bool {
        guard let index = steps.firstIndex(of: step) else { return false }
        return isFinished || index < activeIndex
    }

    func buttonTitle(for step: PerbaikiStep) -> String {
        step == steps.last ? "Selesai" : "Selanjutnya"
    }

    /// The bath volume after the water was added (V2, L); nil until the soda could be worked out.
    var volumeBakLiter: Double? {
        penambahanSoda?.volumeSekarang
    }

    /// Completes the active step and activates the next one; the last step finishes the guide.
    /// Confirming the water step takes `waterPH`, the live pH after the water (pH2), to work out the soda.
    func lanjut(waterPH: Double? = nil) {
        guard !isFinished else { return }
        if steps[activeIndex] == .air, let proyek, let pHSebelum, let waterPH {
            penambahanSoda = proyek.penambahanSoda(
                pHSebelum: pHSebelum,
                pHSesudah: waterPH,
                airDitambahkanLiter: Double(jumlahAir)
            )
        }
        if activeIndex == steps.count - 1 {
            isFinished = true
        } else {
            activeIndex += 1
        }
    }
}
