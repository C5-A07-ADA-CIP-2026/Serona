@testable import Serona
import Testing

struct DiscoveredDeviceNameTests {
    @Test("The advertised name wins over the name iOS cached for the peripheral")
    func advertisedNameWinsOverCachedName() {
        let name = DiscoveredDevice.resolveName(peripheralName: "ESP 32", advertisedName: "Serona-A1B2C3D4")

        #expect(name == "Serona-A1B2C3D4")
    }

    @Test("Falls back to the peripheral name when the advertisement has none")
    func fallsBackToPeripheralName() {
        let name = DiscoveredDevice.resolveName(peripheralName: "Serona-A1B2C3D4", advertisedName: nil)

        #expect(name == "Serona-A1B2C3D4")
    }

    @Test("Blank names count as missing")
    func blankNamesAreIgnored() {
        let name = DiscoveredDevice.resolveName(peripheralName: "  ", advertisedName: "")

        #expect(name == nil)
    }

    @Test("No name at all resolves to nil, so the caller can tell it from a real name")
    func noNameResolvesToNil() {
        #expect(DiscoveredDevice.resolveName(peripheralName: nil, advertisedName: nil) == nil)
    }
}
