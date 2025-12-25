import SwiftUI

struct AppTheme {
    let backgroundGradient: LinearGradient
    let cardBackground: Color
    let textPrimary: Color
    let textSecondary: Color
    let accent: Color
    let success: Color
    let warning: Color
    let actionPrimary: Color
    let actionSecondary: Color
}

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    // MARK: - Legacy Color Picker Support
    // We keep this to allow users to pick an "Accent" that might be used for buttons or highlights,
    // overriding the theme's default accent if desired, or we can just keep it for backward compatibility
    // until we fully refactor.

    static let availableColors: [(name: String, color: Color)] = [
        ("Grimace Purple", Color(hex: "#894fa3")),
        ("Ocean Blue", Color(hex: "#007aff")),
        ("Mint Fresh", Color(hex: "#00c6bf")),
        ("Lime Zest", Color(hex: "#7fd800")),
        ("Sunset Coral", Color(hex: "#ff5966")),
        ("Hot Pink", Color(hex: "#ff2da5")),
        ("Tangerine", Color(hex: "#ff9300")),
        ("Lavender Dream", Color(hex: "#ba8eff")),
        ("San Diego Merlot", Color(hex: "#7a1e3a")),
        ("Forest Green", Color(hex: "#0b6e4f")),
        ("Miami Vice", Color(hex: "#ff6ec7")),
        ("Electric Lemonade", Color(hex: "#ccff00")),
        ("Neon Grape", Color(hex: "#b026ff")),
        ("Slate Stone", Color(hex: "#708090")),
        ("Warm Sandstone", Color(hex: "#c4a77d")),
    ]

    private static let defaultColorName = "Grimace Purple"

    @AppStorage("foqosThemeColorName", store: UserDefaults(suiteName: "group.dev.ambitionsoftware.foqos"))
    var themeColorName: String = defaultColorName {
        didSet {
            objectWillChange.send()
        }
    }

    var selectedColorName: String {
        get { themeColorName }
        set {
            themeColorName = newValue
            objectWillChange.send()
        }
    }

    var themeColor: Color {
        Self.availableColors.first(where: { $0.name == themeColorName })?.color
            ?? Self.availableColors.first!.color
    }

    func setTheme(named name: String) {
        selectedColorName = name
    }

    // MARK: - New Global Theme Palettes

    // Night Sky (Twilight) - Dark Mode
    private static let nightTheme = AppTheme(
        backgroundGradient: LinearGradient(
            colors: [
                Color(hex: "#0c1445"), // Deep Midnight Blue
                Color(hex: "#2c1e5e")  // Deep Twilight Purple
            ],
            startPoint: .top,
            endPoint: .bottom
        ),
        cardBackground: Color(hex: "#1c2559").opacity(0.8),
        textPrimary: .white,
        textSecondary: Color(hex: "#a3b1d6"),
        accent: Color(hex: "#ffd700"), // Moon Gold
        success: Color(hex: "#4cd964"),
        warning: Color(hex: "#ffcc00"),
        actionPrimary: Color(hex: "#4f5bd5"),
        actionSecondary: Color(hex: "#3d426b")
    )

    // Sunset - Light Mode
    private static let sunsetTheme = AppTheme(
        backgroundGradient: LinearGradient(
            colors: [
                Color(hex: "#ff9966"), // Orange
                Color(hex: "#ff5e62")  // Red-Pink
            ],
            startPoint: .top,
            endPoint: .bottom
        ),
        cardBackground: Color.white.opacity(0.85),
        textPrimary: Color(hex: "#2d1b2e"),
        textSecondary: Color(hex: "#5c4b5e"),
        accent: Color(hex: "#2d1b2e"),
        success: Color(hex: "#34c759"),
        warning: Color(hex: "#ff9500"),
        actionPrimary: Color(hex: "#2b1c40"),
        actionSecondary: Color.white.opacity(0.5)
    )

    // MARK: - State

    @AppStorage("foqosThemeMode", store: UserDefaults(suiteName: "group.dev.ambitionsoftware.foqos"))
    var themeMode: ThemeMode = .system {
        didSet {
            objectWillChange.send()
        }
    }

    // Helper to access the current theme properties
    func currentTheme(for scheme: ColorScheme) -> AppTheme {
        // We can optionally mix in the 'themeColor' into the AppTheme here if we want the user choice to override defaults
        let base: AppTheme
        switch themeMode {
        case .light:
            base = Self.sunsetTheme
        case .dark:
            base = Self.nightTheme
        case .system:
            base = scheme == .dark ? Self.nightTheme : Self.sunsetTheme
        }

        // Return base theme but layout logic can fallback to 'themeColor' if needed
        return base
    }

    var colorScheme: ColorScheme? {
        switch themeMode {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    enum ThemeMode: String, CaseIterable, Identifiable {
        case system = "System"
        case light = "Sunset"
        case dark = "Night Sky"

        var id: String { rawValue }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a: UInt64
        let r: UInt64
        let g: UInt64
        let b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    func toHex() -> String? {
        let uiColor = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0

        guard uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) else {
            return nil
        }

        let rgb: Int = (Int)(r * 255) << 16 | (Int)(g * 255) << 8 | (Int)(b * 255) << 0

        return String(format: "#%06x", rgb)
    }
}
