import SwiftUI
import Combine
import UIKit

// MARK: - Theme Color Options

enum ThemeColor: String, CaseIterable {
    case neonGreen
    case neonPink
    case neonBlue
    case neonRed

    /// User-facing label (raw values stay stable for UserDefaults).
    var displayName: String {
        switch self {
        case .neonGreen: return "Aurora"
        case .neonPink: return "Rose"
        case .neonBlue: return "Sapphire"
        case .neonRed: return "Ember"
        }
    }

    var accent: Color {
        switch self {
        case .neonGreen:
            // Aurora: electric mint / cyan-green (distinct from blue Sapphire)
            return Color(red: 0.12, green: 0.92, blue: 0.68)
        case .neonPink:
            return Color(red: 0.98, green: 0.22, blue: 0.62)
        case .neonBlue:
            // Sapphire: saturated jewel blue
            return Color(red: 0.22, green: 0.45, blue: 1.0)
        case .neonRed:
            return Color(red: 1.0, green: 0.32, blue: 0.22)
        }
    }

    /// Slightly brighter partner for gradients and glows.
    var accentHighlight: Color {
        switch self {
        case .neonGreen:
            return Color(red: 0.45, green: 1.0, blue: 0.88)
        case .neonPink:
            return Color(red: 1.0, green: 0.55, blue: 0.82)
        case .neonBlue:
            return Color(red: 0.55, green: 0.72, blue: 1.0)
        case .neonRed:
            return Color(red: 1.0, green: 0.62, blue: 0.45)
        }
    }

    var accentSoft: Color { accent.opacity(0.55) }
    var accentDeep: Color { accent.opacity(0.92) }

    /// Stable `UIColor` for UIKit tab bar / toolbars (must match `accent` RGB exactly).
    var uiAccent: UIColor {
        switch self {
        case .neonGreen:
            return UIColor(red: 0.12, green: 0.92, blue: 0.68, alpha: 1)
        case .neonPink:
            return UIColor(red: 0.98, green: 0.22, blue: 0.62, alpha: 1)
        case .neonBlue:
            return UIColor(red: 0.22, green: 0.45, blue: 1.0, alpha: 1)
        case .neonRed:
            return UIColor(red: 1.0, green: 0.32, blue: 0.22, alpha: 1)
        }
    }
}

// MARK: - Theme Manager

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    private let storageKey = "selectedTheme"

    @Published var selectedTheme: ThemeColor = .neonGreen {
        didSet {
            UserDefaults.standard.set(selectedTheme.rawValue, forKey: storageKey)
        }
    }

    private init() {
        if let savedRawValue = UserDefaults.standard.string(forKey: storageKey),
           let savedTheme = ThemeColor(rawValue: savedRawValue) {
            self.selectedTheme = savedTheme
        }
    }

    var accent: Color { selectedTheme.accent }
    var accentHighlight: Color { selectedTheme.accentHighlight }
    var accentSoft: Color { selectedTheme.accentSoft }
    var accentDeep: Color { selectedTheme.accentDeep }
}

// MARK: - App Theme Styling

enum AppTheme {
    /// Login, email verification, and onboarding: always **dark** UI + **Sapphire** (`ThemeColor.neonBlue`) accents. User’s saved theme and appearance only apply in the main app.
    enum AuthFlow {
        private static let sapphire = ThemeColor.neonBlue

        static let background = Color(red: 0.05, green: 0.07, blue: 0.15)
        static let card = Color(red: 0.10, green: 0.12, blue: 0.22)
        static let cardSecondary = Color(red: 0.13, green: 0.16, blue: 0.27)
        static let textPrimary = Color(red: 0.96, green: 0.97, blue: 0.99)
        static let textSecondary = Color(red: 0.62, green: 0.66, blue: 0.78)

        static var accent: Color { sapphire.accent }
        static var accentSoft: Color { sapphire.accentSoft }

        static var accentGradient: LinearGradient {
            AppTheme.vibrantAccentGradient(accent: sapphire.accent, highlight: sapphire.accentHighlight)
        }

        static var outlineGradient: LinearGradient {
            LinearGradient(
                colors: [sapphire.accent.opacity(0.5), sapphire.accent.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        static func cardBorder(accent: Color) -> Color {
            accent.opacity(0.38)
        }
    }

    static let success = Color(red: 0.22, green: 0.72, blue: 0.52)
    static let danger = Color(red: 0.90, green: 0.32, blue: 0.28)

    /// Default CTA gradient when no `ThemeManager` is in scope (e.g. previews).
    static let cheerfulGradient = LinearGradient(
        colors: [
            ThemeColor.neonBlue.accentHighlight,
            ThemeColor.neonBlue.accent
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func background(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.07, green: 0.08, blue: 0.11)
            : Color(red: 0.96, green: 0.97, blue: 0.99)
    }

    static func card(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(red: 0.11, green: 0.12, blue: 0.16) : Color.white
    }

    static func cardSecondary(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(red: 0.15, green: 0.16, blue: 0.20) : Color(red: 0.94, green: 0.95, blue: 0.98)
    }

    static func cardBorder(for colorScheme: ColorScheme, accent: Color) -> Color {
        colorScheme == .dark ? accent.opacity(0.38) : accent.opacity(0.22)
    }

    static func textPrimary(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(red: 0.96, green: 0.97, blue: 0.99) : Color(red: 0.09, green: 0.11, blue: 0.16)
    }

    static func textSecondary(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(red: 0.62, green: 0.66, blue: 0.74) : Color(red: 0.42, green: 0.46, blue: 0.55)
    }

    static func accentGradient(_ accent: Color) -> LinearGradient {
        LinearGradient(
            colors: [accent, accent.opacity(0.68)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Stronger two-stop gradient when `ThemeManager` is available (more vibrant UI).
    static func vibrantAccentGradient(accent: Color, highlight: Color) -> LinearGradient {
        LinearGradient(
            colors: [highlight, accent],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

extension ThemeManager {
    /// Brighter two-stop gradient for buttons and key accents (uses theme highlight + base accent).
    var vividAccentGradient: LinearGradient {
        AppTheme.vibrantAccentGradient(accent: accent, highlight: accentHighlight)
    }
}
