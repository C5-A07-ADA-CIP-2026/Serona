enum AppTab: CaseIterable {
    case proyek
    case resep

    var title: String {
        switch self {
        case .resep: "Warna"
        case .proyek: "Proyek"
        }
    }

    var systemImage: String {
        switch self {
        case .resep: "book"
        case .proyek: "folder"
        }
    }
}
