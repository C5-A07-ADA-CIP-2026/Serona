//
//  TambahProyekViewModel.swift
//  Serona
//

import Foundation
import Observation

/// The "Tambahkan Proyek" form: name, device, color (a recipe) and amount of fabric.
@MainActor
@Observable
final class TambahProyekViewModel {
    var nama = ""
    var jumlahKain = 0
    var namaPemesan = ""
    var jumlahAir = 0
    private(set) var perangkat: DiscoveredDevice?
    private(set) var resep: Resep?
    private(set) var saveError: String?
    private var isSaved = false
    private let service: any DeviceConnecting

    init(service: (any DeviceConnecting)? = nil) {
        self.service = service ?? DeviceConnectionServices.default
    }

    var canSubmit: Bool {
        nama.tidakKosong && perangkat != nil && resep != nil && jumlahKain > 0
    }

    var canSubmitScan: Bool {
        perangkat != nil && resep != nil && namaPemesan.tidakKosong && jumlahAir > 0
    }

    func pilihPerangkat(_ perangkat: DiscoveredDevice) {
        self.perangkat = perangkat
    }

    /// Clears the chosen device and drops its connection.
    func hapusPerangkat() async {
        guard let perangkat else { return }
        self.perangkat = nil
        await service.disconnect(from: perangkat)
    }

    func pilihResep(_ resep: Resep) {
        self.resep = resep
    }

    func hapusResep() {
        resep = nil
    }

    /// Inserts the new active project. Returns nil, and changes nothing, when the form is incomplete,
    /// was saved already, or the save fails (the form is kept so the user can retry).
    @discardableResult
    func simpan(in persistence: some ModelPersisting) -> Proyek? {
        guard canSubmit, !isSaved, let perangkat, let resep else { return nil }

        let proyek = Proyek(
            nama: nama.trimmingCharacters(in: .whitespacesAndNewlines),
            perangkatNama: perangkat.nama,
            resep: resep,
            jumlahKain: jumlahKain
        )
        do {
            try persistence.insertAndSave(proyek)
        } catch {
            saveError = "Gagal menyimpan proyek: \(error.localizedDescription)"
            return nil
        }
        isSaved = true
        return proyek
    }

    /// Updates an existing Stage 3 Bak project with the chosen device, recipe, customer name, and water volume,
    /// then marks it active so scanning can start immediately.
    @discardableResult
    func simpanUntukPindai(_ proyek: Proyek, in persistence: some ModelPersisting) -> Bool {
        guard canSubmitScan, let resep else { return false }

        proyek.batalkanSelesai()
        proyek.perangkatNama = namaPemesan.trimmingCharacters(in: .whitespacesAndNewlines)
        proyek.namaWarna = resep.namaWarna
        proyek.warnaHex = resep.warnaHex
        proyek.batasKepekatan = ProyekDetailViewModel.defaultConcentrationLimit
        proyek.batasPH = ProyekDetailViewModel.defaultWaterPHLimit
        proyek.pewarna = resep.pewarna
        proyek.zatPembantu = resep.zatPembantu
        proyek.air = jumlahAir * 1000
        proyek.jumlahKain = max(1, proyek.jumlahKain)
        proyek.resep = resep
        proyek.tanggal = .now
        proyek.visibleAverageAwal = nil
        proyek.phAwal = nil
        proyek.rasioAwal = nil
        proyek.rasioAirBersih = nil

        do {
            try persistence.save()
        } catch {
            saveError = "Gagal menyimpan proyek: \(error.localizedDescription)"
            return false
        }
        isSaved = true
        return true
    }

    func clearSaveError() {
        saveError = nil
    }
}
