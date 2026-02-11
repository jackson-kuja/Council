import SwiftUI

enum AppColors {
    // MARK: - Backgrounds
    static let background = Color(hex: "FFFFFF")
    static let surface = Color(hex: "F7F7F8")
    static let surfaceElevated = Color(hex: "EDEDEF")

    // MARK: - Accents
    static let accent = Color(hex: "000000")
    static let accentSecondary = Color(hex: "6B6B6B")

    // MARK: - Text
    static let textPrimary = Color(hex: "111111")
    static let textSecondary = Color(hex: "6B6B6B")
    static let textTertiary = Color(hex: "9E9E9E")

    // MARK: - Border
    static let border = Color(hex: "E5E5E5")

    // MARK: - Semantic
    static let success = Color(hex: "22C55E")
    static let error = Color(hex: "EF4444")
    static let warning = Color(hex: "F59E0B")

    // MARK: - Voice Session (immersive dark)
    static let sessionBackground = Color(hex: "0A0A0A")
    static let sessionText = Color.white
    static let sessionTextSecondary = Color(hex: "999999")

    // MARK: - Category Gradients
    static let categoryProductivity = (Color(hex: "6366F1"), Color(hex: "8B5CF6"))
    static let categoryMindset = (Color(hex: "EC4899"), Color(hex: "F43F5E"))
    static let categoryCareer = (Color(hex: "3B82F6"), Color(hex: "06B6D4"))
    static let categoryHealth = (Color(hex: "10B981"), Color(hex: "34D399"))
    static let categoryCreativity = (Color(hex: "F97316"), Color(hex: "FBBF24"))
    static let categoryCustom = (Color(hex: "8B5CF6"), Color(hex: "D946EF"))

    static func gradientForCategory(_ category: String) -> (Color, Color) {
        switch category.lowercased() {
        case "productivity": return categoryProductivity
        case "mindset": return categoryMindset
        case "career": return categoryCareer
        case "health": return categoryHealth
        case "creativity": return categoryCreativity
        default: return categoryCustom
        }
    }

    // MARK: - Orb Color Pairs (for coaches)
    static let orbPalettes: [(Color, Color)] = [
        (Color(hex: "6366F1"), Color(hex: "818CF8")),
        (Color(hex: "EC4899"), Color(hex: "F472B6")),
        (Color(hex: "10B981"), Color(hex: "34D399")),
        (Color(hex: "3B82F6"), Color(hex: "60A5FA")),
        (Color(hex: "F97316"), Color(hex: "FB923C")),
        (Color(hex: "8B5CF6"), Color(hex: "A78BFA")),
        (Color(hex: "14B8A6"), Color(hex: "2DD4BF")),
        (Color(hex: "F43F5E"), Color(hex: "FB7185")),
    ]
}

// MARK: - Color Extension for Hex

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
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
