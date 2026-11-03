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

    let steps: [PerbaikiStep]
    let proyek: Proyek?
    var jumlahAir = 7
    private(set) var isFinished = false
    /// The soda to add, known once the water step was confirmed with a pH before and after the water.
    private(set) var penambahanSoda: PenambahanSoda?
    private let pHSebelum: Double?
    private var activeIndex = 0

    /// `pHSebelum` is the pH when the limit was crossed, before any water is added (pH1).
    init(issue: QualityIssue, proyek: Proyek? = nil, pHSebelum: Double? = nil) {
        self.proyek = proyek
        self.pHSebelum = pHSebelum
        steps = switch issue {
        case .kepekatan: [.air, .kepekatan]
        case .phAir: [.air, .phAir]
        case .keduanya: [.air, .phAir, .kepekatan]
        }
    }

    func isActive(_ step: PerbaikiStep) -> Bool {
        !isFinished && steps[activeIndex] == step
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
