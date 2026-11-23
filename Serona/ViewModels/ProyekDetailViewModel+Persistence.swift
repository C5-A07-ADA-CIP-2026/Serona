//
//  ProyekDetailViewModel+Persistence.swift
//  Serona
//

import Foundation

/// Finishing a bath and switching its device, both of which save the project and roll back when saving fails.
extension ProyekDetailViewModel {
    /// Finishes the active bath: clears all saved bath data and resets the bak to unused (`nonaktif`).
    @discardableResult
    func selesaikan(in persistence: some ModelPersisting) -> Bool {
        guard proyek.status == .aktif else { return false }

        let savedName = proyek.namaWarna
        let savedHex = proyek.warnaHex
        let savedDeviceName = proyek.perangkatNama
        let savedDeviceID = proyek.perangkatID
        let savedPewarna = proyek.pewarna
        let savedZat = proyek.zatPembantu
        let savedAir = proyek.airTersimpan
        let savedAirResep = proyek.airResepTersimpan
        let savedResep = proyek.resep
        let savedBaseline = proyek.visibleAverageAwal
        let savedRasio = proyek.rasioAwal
        let savedAirBersih = proyek.rasioAirBersih
        let savedPHAwal = proyek.phAwal

        proyek.selesaikan()
        do {
            try persistence.save()
        } catch {
            proyek.batalkanSelesai()
            proyek.namaWarna = savedName
            proyek.warnaHex = savedHex
            proyek.perangkatNama = savedDeviceName
            proyek.perangkatID = savedDeviceID
            proyek.pewarna = savedPewarna
            proyek.zatPembantu = savedZat
            proyek.airTersimpan = savedAir
            proyek.airResepTersimpan = savedAirResep
            proyek.resep = savedResep
            proyek.visibleAverageAwal = savedBaseline
            proyek.rasioAwal = savedRasio
            proyek.rasioAirBersih = savedAirBersih
            proyek.phAwal = savedPHAwal
            saveError = "Gagal menyimpan proyek: \(error.localizedDescription)"
            return false
        }
        clearRepairGuide()
        berhenti()
        return true
    }

    /// Points the active bath at `device` after reconnecting to another sensor, keeping all saved bath data.
    @discardableResult
    func gantiPerangkat(_ device: DiscoveredDevice, in persistence: some ModelPersisting) -> Bool {
        guard proyek.status == .aktif else { return false }

        let sebelumnya = proyek.perangkatNama
        let idSebelumnya = proyek.perangkatID
        proyek.perangkatNama = device.nama
        proyek.perangkatID = device.id
        do {
            try persistence.save()
        } catch {
            proyek.perangkatNama = sebelumnya
            proyek.perangkatID = idSebelumnya
            saveError = "Gagal menyimpan proyek: \(error.localizedDescription)"
            return false
        }
        return true
    }

    /// Switches the project to `device` (see `gantiPerangkat`) and reconnects with saved bath data intact.
    @discardableResult
    func pindahPerangkat(_ device: DiscoveredDevice, in persistence: some ModelPersisting) async -> Bool {
        guard gantiPerangkat(device, in: persistence) else { return false }
        await sambungkanUlang(in: persistence)
        return true
    }
}
