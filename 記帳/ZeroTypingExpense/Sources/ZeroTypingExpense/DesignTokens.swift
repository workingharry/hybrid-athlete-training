import SwiftUI

public enum DesignTokens {
    public enum Colors {
        // Light Mode Tokens (§2.1)
        public static let bgLight = Color(red: 0xF7/255.0, green: 0xF6/255.0, blue: 0xF2/255.0)
        public static let surfaceLight = Color(red: 1.0, green: 1.0, blue: 1.0)
        public static let textPrimaryLight = Color(red: 0x14/255.0, green: 0x14/255.0, blue: 0x13/255.0)
        public static let textSecondaryLight = Color(red: 0x65/255.0, green: 0x63/255.0, blue: 0x5D/255.0)
        public static let accentLight = Color(red: 0xC1/255.0, green: 0x2E/255.0, blue: 0x18/255.0)
        public static let dividerLight = Color(red: 0xE5/255.0, green: 0xE2/255.0, blue: 0xDA/255.0)
        public static let successLight = Color(red: 0x21/255.0, green: 0x6B/255.0, blue: 0x4A/255.0)
        public static let warningLight = Color(red: 0x87/255.0, green: 0x55/255.0, blue: 0x00/255.0)
        public static let errorLight = Color(red: 0xB4/255.0, green: 0x23/255.0, blue: 0x18/255.0)

        // Dark Mode Tokens (§2.1)
        public static let bgDark = Color(red: 0x12/255.0, green: 0x12/255.0, blue: 0x12/255.0)
        public static let surfaceDark = Color(red: 0x1E/255.0, green: 0x1E/255.0, blue: 0x1E/255.0)
        public static let textPrimaryDark = Color(red: 0xF7/255.0, green: 0xF6/255.0, blue: 0xF2/255.0)
        public static let textSecondaryDark = Color(red: 0xB8/255.0, green: 0xB6/255.0, blue: 0xAE/255.0)
        public static let accentDark = Color(red: 0xFF/255.0, green: 0x76/255.0, blue: 0x5E/255.0)
        public static let dividerDark = Color(red: 0x33/255.0, green: 0x33/255.0, blue: 0x33/255.0)
        public static let successDark = Color(red: 0x70/255.0, green: 0xC6/255.0, blue: 0x9A/255.0)
        public static let warningDark = Color(red: 0xF2/255.0, green: 0xC3/255.0, blue: 0x6B/255.0)
        public static let errorDark = Color(red: 0xFF/255.0, green: 0x8A/255.0, blue: 0x80/255.0)
    }

    public enum Spacing {
        public static let xs: CGFloat = 4
        public static let s: CGFloat = 8
        public static let m: CGFloat = 12
        public static let l: CGFloat = 16
        public static let xl: CGFloat = 20
        public static let xxl: CGFloat = 24
        public static let xxxl: CGFloat = 32
    }

    public enum Layout {
        public static let minTouchTarget: CGFloat = 48
        public static let cardCornerRadius: CGFloat = 18
    }
}

public extension DesignTokens.Colors {
    static var backgroundLight: Color { bgLight }
    static var backgroundDark: Color { bgDark }
    static var dangerLight: Color { errorLight }
}

public extension DesignTokens.Layout {
    static let buttonCornerRadius: CGFloat = 12
}

public extension Color {
    init(hex: String) {
        let cleanHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch cleanHex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
