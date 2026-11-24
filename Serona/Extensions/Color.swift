import SwiftUI

extension Color {
    static let oliveGreenText = Color(red: 0.37, green: 0.42, blue: 0)

    static let peringatan = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? .systemRed : UIColor(red: 0.77, green: 0.125, blue: 0.11, alpha: 1)
    })

    static let latarPeringatan = Color(red: 0.77, green: 0.125, blue: 0.11)

    init(hex: String) {
        let scanner = Scanner(string: hex)
        _ = scanner.scanString("#")

        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)

        let red = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let green = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let blue = Double(rgbValue & 0x0000FF) / 255.0

        self.init(red: red, green: green, blue: blue)
    }

    init?(hex: String?) {
        guard let hex, !hex.isEmpty else { return nil }
        self.init(hex: hex)
    }

    var hexString: String {
        let components = Self.srgbComponents(of: UIColor(self))
        return "#" + components.map(Self.hexByte).joined()
    }

    private static func srgbComponents(of color: UIColor) -> [CGFloat] {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        if color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return [red, green, blue]
        }

        let srgb = CGColorSpace(name: CGColorSpace.sRGB)
        let converted = srgb.flatMap { color.cgColor.converted(to: $0, intent: .defaultIntent, options: nil) }
        guard let values = converted?.components, values.count >= 3 else { return [0, 0, 0] }
        return Array(values.prefix(3))
    }

    private static func hexByte(_ component: CGFloat) -> String {
        let clamped = min(max(component, 0), 1)
        let byte = UInt8((clamped * 255).rounded())
        let digits = String(byte, radix: 16, uppercase: true)
        return digits.count == 1 ? "0" + digits : digits
    }
}
