//
//  TambahProyekView+Save.swift
//  Serona
//

import SwiftData
import SwiftUI

extension TambahProyekView {
    // MARK: - Save Action

    func simpanProyek() {
        guard canSubmit, let perangkat = viewModel.perangkat, let resep = viewModel.resep else { return }
        let airLiter = viewModel.jumlahAir > 0 ? viewModel.jumlahAir : resep.air

        if let existingProyek {
            resetForReuse(existingProyek, perangkat: perangkat, resep: resep, airLiter: airLiter)

            do {
                try modelContext.save()
                onProyekCreated?(existingProyek)
                dismiss()
            } catch {
                saveErrorMessage = "Gagal menyimpan proyek: \(error.localizedDescription)"
            }
            return
        }

        let newProyek = Proyek(
            nama: resolvedBakTitle,
            perangkatNama: perangkat.nama,
            perangkatID: perangkat.id,
            resep: resep,
            jumlahKain: 1,
            tanggal: .now
        )
        newProyek.batasKepekatan = ProyekDetailViewModel.defaultConcentrationLimit
        newProyek.batasPH = ProyekDetailViewModel.defaultWaterPHLimit
        newProyek.air = airLiter
        newProyek.rasioAirBersih = ProyekDetailViewModel.defaultCleanWaterRatios

        modelContext.insert(newProyek)
        do {
            try modelContext.save()
            onProyekCreated?(newProyek)
            dismiss()
        } catch {
            modelContext.delete(newProyek)
            saveErrorMessage = "Gagal menyimpan proyek: \(error.localizedDescription)"
        }
    }

    /// Starts an existing bath over with the chosen device and recipe: the old readings and baselines are cleared.
    private func resetForReuse(_ proyek: Proyek, perangkat: DiscoveredDevice, resep: Resep, airLiter: Int) {
        proyek.perangkatNama = perangkat.nama
        proyek.perangkatID = perangkat.id
        proyek.resep = resep
        proyek.namaWarna = resep.namaWarna
        proyek.warnaHex = resep.warnaHex
        proyek.pewarna = resep.pewarna
        proyek.zatPembantu = resep.zatPembantu
        proyek.airResepTersimpan = resep.air
        proyek.jumlahKain = 1
        proyek.tanggal = .now
        proyek.status = .aktif
//        proyek.tanggalSelesai = nil
        proyek.visibleAverageAwal = nil
        proyek.rasioAwal = nil
        proyek.phAwal = nil
        proyek.kepekatanAkhir = nil
        proyek.phAkhir = nil
        proyek.batasKepekatan = ProyekDetailViewModel.defaultConcentrationLimit
        proyek.batasPH = ProyekDetailViewModel.defaultWaterPHLimit
        proyek.air = airLiter
        proyek.rasioAirBersih = ProyekDetailViewModel.defaultCleanWaterRatios
    }
}
