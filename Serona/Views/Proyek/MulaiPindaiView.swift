//
//  MulaiPindaiView.swift
//  Serona
//
//  Created by Steffany Florence on 14/11/26.
//

import SwiftData
import SwiftUI

struct MulaiPindaiSheetView: View {
    let proyek: Proyek
    var deviceService: (any DeviceConnecting)? = nil
    var onStartScan: (Proyek) -> Void

    var body: some View {
        TambahProyekView(
            existingProyek: proyek,
            deviceService: deviceService,
            onProyekCreated: onStartScan
        )
    }
}
