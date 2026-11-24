@testable import Serona
import Testing

@MainActor
struct AppTabTests {
    @Test func proyekIsTheFirstTab() {
        #expect(AppTab.allCases.first == .proyek)
    }

    @Test func resepFollowsProyek() {
        #expect(AppTab.allCases == [.proyek, .resep])
    }

    @Test func tabsHaveTitles() {
        #expect(AppTab.resep.title == "Warna")
        #expect(AppTab.proyek.title == "Proyek")
    }

    @Test func tabsHaveIcons() {
        #expect(AppTab.resep.systemImage == "book")
        #expect(AppTab.proyek.systemImage == "folder")
    }
}
