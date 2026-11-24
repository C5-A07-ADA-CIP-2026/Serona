import SwiftData
import SwiftUI

struct MulaiPindaiSheetView: View {
    let proyek: Proyek
    var deviceService: (any DeviceConnecting)?
    var onStartScan: (Proyek) -> Void

    var body: some View {
        TambahProyekView(
            existingProyek: proyek,
            deviceService: deviceService,
            onProyekCreated: onStartScan
        )
    }
}
