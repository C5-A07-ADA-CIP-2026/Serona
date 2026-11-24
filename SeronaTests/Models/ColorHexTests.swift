@testable import Serona
import SwiftUI
import Testing

@Suite("Color hex")
@MainActor
struct ColorHexTests {
    @Test("Round-trips hex colors", arguments: ["#B50202", "#F4A9B4"])
    func hexStringRoundTrips(hex: String) {
        #expect(Color(hex: hex).hexString == hex)
    }

    @Test("Black and white")
    func blackAndWhite() {
        #expect(Color(hex: "#000000").hexString == "#000000")
        #expect(Color(hex: "#FFFFFF").hexString == "#FFFFFF")
        #expect(Color.black.hexString == "#000000")
        #expect(Color.white.hexString == "#FFFFFF")
    }

    @Test("Out-of-gamut colors still produce a well-formed hex")
    func outOfGamutIsClamped() {
        let displayP3Red = Color(.displayP3, red: 1, green: 0, blue: 0)
        let extended = Color(UIColor(
            red: 1.2, green: -0.3, blue: 0.5, alpha: 1
        ))

        for color in [displayP3Red, extended] {
            let hex = color.hexString
            #expect(hex.wholeMatch(of: /#[0-9A-F]{6}/) != nil, "got \(hex)")
            #expect(Color(hex: hex).hexString == hex)
        }
    }
}
