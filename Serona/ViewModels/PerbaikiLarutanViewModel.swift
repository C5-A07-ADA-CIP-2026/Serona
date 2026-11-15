//
//  PerbaikiLarutanViewModel.swift
//  Serona
//

import Foundation
import Observation

enum PerbaikiStep: Equatable {
    case air
    case phAir
    case kepekatan
}

@MainActor
@Observable
final class PerbaikiLarutanViewModel {
    static let gramSodaAbu = 10
    static let gramPewarna = 10
    static let targetPH: Double = 12.0
    static let targetConcentration: Double = 100.0

    private(set) var issue: QualityIssue
    private(set) var steps: [PerbaikiStep]
    let proyek: Proyek?
    var jumlahAir = 0
    private(set) var isFinished = false
    private(set) var penambahanSoda: PenambahanSoda?
    private let pHSebelum: Double?
    private(set) var activeIndex = 0

    /// `pHSebelum` is the pH when the limit was crossed, before any water is added (pH1).
    init(
        issue: QualityIssue,
        proyek: Proyek? = nil,
        pHSebelum: Double? = nil,
        initialStep: PerbaikiStep = .air,
        initialJumlahAir: Int = 0
    ) {
        self.issue = issue
        self.proyek = proyek
        self.pHSebelum = pHSebelum
        self.jumlahAir = initialJumlahAir
        let resolvedSteps = Self.calculateSteps(for: issue, existingSteps: [])
        self.steps = resolvedSteps
        self.activeIndex = resolvedSteps.firstIndex(of: initialStep) ?? 0
    }

    func updateIssue(_ newIssue: QualityIssue) {
        guard newIssue != issue else { return }
        let combined = issue.combining(with: newIssue)
        issue = combined
        steps = Self.calculateSteps(for: combined, existingSteps: steps)
    }

    private static func calculateSteps(for _: QualityIssue, existingSteps _: [PerbaikiStep]) -> [PerbaikiStep] {
        [.air, .phAir, .kepekatan]
    }

    var currentStep: PerbaikiStep {
        guard activeIndex < steps.count else { return .kepekatan }
        return steps[activeIndex]
    }

    var jumlahAirFormatted: String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "id_ID")
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: jumlahAir)) ?? "\(jumlahAir)"
    }

    var totalVolumeLiter: Double {
        let baseVolume = (proyek?.volumeResepLiter ?? 0) > 0 ? (proyek?.volumeResepLiter ?? 1.0) : 1.0
        return baseVolume + Double(max(0, jumlahAir))
    }

    var volumeBakLiter: Double? {
        penambahanSoda?.volumeSekarang ?? totalVolumeLiter
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

    func canProceed(currentPH: Double?, currentConcentration: Double?) -> Bool {
        switch currentStep {
        case .air:
            return jumlahAir > 0
        case .phAir:
            guard let currentPH else { return false }
            return currentPH >= Self.targetPH
        case .kepekatan:
            guard let currentConcentration else { return false }
            return currentConcentration >= Self.targetConcentration
        }
    }

    func sodaAdditions(currentPH: Double?) -> [Bahan] {
        let phNow = currentPH ?? pHSebelum ?? 8.0
        let remainingFraction = min(1.0, max(0.0, pow(10, phNow - Self.targetPH)))

        if let proyek, proyek.volumeResepLiter > 0, !proyek.zatPembantu.isEmpty {
            let baseVolume = proyek.volumeResepLiter
            let targetGramPerLiter = proyek.targetSodaGramPerLiter
            let effectiveUnalkalizedVolume = max(0, totalVolumeLiter - (baseVolume * remainingFraction))
            let totalSodaGram = targetGramPerLiter * effectiveUnalkalizedVolume
            let totalRecipeZat = proyek.zatPembantu.reduce(0) { $0 + $1.gram }

            return proyek.zatPembantu.map { bahan in
                let share = totalRecipeZat > 0 ? (bahan.gram / totalRecipeZat) : 1.0
                return Bahan(kode: bahan.kode.lowercased(), gram: max(0, totalSodaGram * share))
            }
        }

        let baseVolume = 1.0
        let effectiveRatio = max(0, (totalVolumeLiter / baseVolume) - remainingFraction)
        let fallbackGram = Double(Self.gramSodaAbu) * effectiveRatio
        return [Bahan(kode: "soda abu", gram: max(0, fallbackGram))]
    }

    func pewarnaAdditions(currentConcentration: Double?) -> [Bahan] {
        let concNow = currentConcentration ?? 72.0

        if let proyek, proyek.volumeResepLiter > 0, !proyek.pewarna.isEmpty {
            return proyek.pewarnaYangDitambah(kepekatan: concNow, volumeLiter: totalVolumeLiter)
        }

        let deficitFraction = max(0, (Self.targetConcentration - concNow) / Self.targetConcentration)
        let fallbackGram = Double(Self.gramPewarna) * (deficitFraction / 0.28) * totalVolumeLiter
        let kode = proyek?.pewarna.first?.kode ?? "Napthol AS"
        return [Bahan(kode: kode, gram: max(0, fallbackGram))]
    }

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
