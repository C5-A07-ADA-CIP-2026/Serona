import Foundation

extension ProyekDetailViewModel {
    static let defaultCleanWaterRatios: [Double] = [
        0.0332,
        0.1796,
        0.3443,
        0.2172,
        0.2633,
        0.2978,
        0.2592,
        0.1365,
    ]

    var isCleanWaterSet: Bool {
        true
    }

    var canSetCleanWater: Bool {
        false
    }

    @discardableResult
    func tetapkanAirBersih(in persistence: some ModelPersisting) -> Bool {
        proyek.rasioAirBersih = Self.defaultCleanWaterRatios
        return save(persistence, undo: {})
    }

    @discardableResult
    func ukurUlangAirBersih(in persistence: some ModelPersisting) -> Bool {
        proyek.rasioAirBersih = Self.defaultCleanWaterRatios
        return save(persistence, undo: {})
    }

    private func saveAirBersih(_ ratios: [Double]?, in persistence: some ModelPersisting) -> Bool {
        let sebelumnya = proyek.rasioAirBersih
        proyek.rasioAirBersih = ratios
        return save(persistence, undo: { proyek.rasioAirBersih = sebelumnya })
    }

    var penambahanPewarna: [Bahan]? {
        penambahanPewarna(volumeLiter: nil)
    }

    func penambahanPewarna(volumeLiter: Double?) -> [Bahan]? {
        guard proyek.rasioAwal != nil, let latestConcentration else { return nil }
        return proyek.pewarnaYangDitambah(kepekatan: latestConcentration, volumeLiter: volumeLiter)
    }
}
