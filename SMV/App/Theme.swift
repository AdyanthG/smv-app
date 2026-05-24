//
//  Theme.swift
//  SMV
//
//  Design system v3 — Ultra-dark minimalism.
//  True black, geometric type, brutal spacing, PSL-accurate tiers.
//

import SwiftUI

// MARK: - Color Palette

extension Color {

    // ── Primary Accent (cold, clinical) ──
    static let smvCyan         = Color(hue: 0.52, saturation: 0.70, brightness: 0.92)
    static let smvAmber        = Color(hue: 0.10, saturation: 0.80, brightness: 0.95)

    // ── Semantic ──
    static let smvEmerald      = Color(hue: 0.42, saturation: 0.60, brightness: 0.78)
    static let smvPink         = Color(hue: 0.95, saturation: 0.55, brightness: 0.88)
    static let smvViolet       = Color(hue: 0.73, saturation: 0.55, brightness: 0.88)

    // ── Surfaces (true OLED black) ──
    static let smvBackground   = Color(red: 0.02, green: 0.02, blue: 0.03)
    static let smvSurface0     = Color(red: 0.05, green: 0.05, blue: 0.07)
    static let smvSurface1     = Color(red: 0.08, green: 0.08, blue: 0.10)
    static let smvSurface2     = Color(red: 0.12, green: 0.12, blue: 0.14)

    // ── Text ──
    static let smvTextPrimary   = Color(white: 0.95)
    static let smvTextSecondary = Color(white: 0.55)
    static let smvTextTertiary  = Color(white: 0.30)

    // ── Score Tiers (mapped to PSL descriptors) ──
    static let tierGigaChad    = Color.smvViolet
    static let tierChad        = Color.smvCyan
    static let tierChadlite    = Color.smvEmerald
    static let tierHTN         = Color.smvAmber
    static let tierMTN         = Color.smvTextSecondary
    static let tierLTN         = Color.smvPink
    static let tierSubhuman    = Color(red: 0.6, green: 0.2, blue: 0.2)
}

// MARK: - Gradients

extension LinearGradient {

    static let brandPrimary = LinearGradient(
        colors: [.smvCyan.opacity(0.9), .smvCyan.opacity(0.6)],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let brandSecondary = LinearGradient(
        colors: [.smvCyan.opacity(0.5), .smvEmerald.opacity(0.5)],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let scoreGlow = LinearGradient(
        colors: [.smvCyan.opacity(0.8), .smvViolet.opacity(0.5)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let surfaceGradient = LinearGradient(
        colors: [.smvSurface1, .smvSurface0],
        startPoint: .top,
        endPoint: .bottom
    )
}

extension AngularGradient {
    static func scoreRing(for score: Double) -> AngularGradient {
        let tier = ScoreTier.from(score: score)
        return AngularGradient(
            colors: [tier.color, tier.color.opacity(0.3), tier.color],
            center: .center,
            startAngle: .degrees(-90),
            endAngle: .degrees(270)
        )
    }
}

// MARK: - Score Tiers (PSL-Accurate)
//
// PSL scale: 0.25–8, midpoint ~4.
// We display as 1–10 for mainstream appeal (PSL + ~1.75).
// Tier thresholds match looksmax.org community standards.

enum ScoreTier: String, Codable, CaseIterable {
    case gigaChad = "Giga Chad"       // PSL 7.25+ → display 9.0+
    case chad = "Chad"                // PSL 6–7.25 → display 7.5–9.0
    case chadlite = "Chadlite"        // PSL 5.5–6 → display 7.0–7.5
    case htn = "HTN"                  // PSL 4.5–5.5 → display 6.0–7.0
    case mtn = "Average"              // PSL 3–4.5 → display 4.5–6.0
    case ltn = "Below Average"        // PSL 1.5–3 → display 3.0–4.5
    case subhuman = "Subhuman"        // PSL 0.25–1.5 → display 1.0–3.0

    var color: Color {
        switch self {
        case .gigaChad:    return .tierGigaChad
        case .chad:        return .tierChad
        case .chadlite:    return .tierChadlite
        case .htn:         return .tierHTN
        case .mtn:         return .tierMTN
        case .ltn:         return .tierLTN
        case .subhuman:    return .tierSubhuman
        }
    }

    var emoji: String {
        switch self {
        case .gigaChad:    return "👑"
        case .chad:        return "💎"
        case .chadlite:    return "🔥"
        case .htn:         return "⭐"
        case .mtn:         return "📊"
        case .ltn:         return "📈"
        case .subhuman:    return "💀"
        }
    }

    var rarity: String {
        switch self {
        case .gigaChad:    return "1 in 8M"
        case .chad:        return "1 in 150K"
        case .chadlite:    return "1 in 4.5K"
        case .htn:         return "1 in 92"
        case .mtn:         return "1 in 2"
        case .ltn:         return "1 in 7"
        case .subhuman:    return "1 in 2K"
        }
    }

    static func from(score: Double) -> ScoreTier {
        switch score {
        case 9.0...:    return .gigaChad
        case 7.5..<9.0: return .chad
        case 7.0..<7.5: return .chadlite
        case 6.0..<7.0: return .htn
        case 4.5..<6.0: return .mtn
        case 3.0..<4.5: return .ltn
        default:        return .subhuman
        }
    }
}

// MARK: - Typography (Sharp, Geometric — SF Pro Default)

struct SMVFont {
    static func displayHero()   -> Font { .system(size: 56, weight: .black, design: .default) }
    static func displayLarge()  -> Font { .system(size: 40, weight: .bold, design: .default) }
    static func displayMedium() -> Font { .system(size: 32, weight: .bold, design: .default) }
    static func displaySmall()  -> Font { .system(size: 24, weight: .bold, design: .default) }
    static func headline()      -> Font { .system(size: 20, weight: .semibold, design: .default) }
    static func title()         -> Font { .system(size: 17, weight: .semibold) }
    static func body()          -> Font { .system(size: 15, weight: .regular) }
    static func caption()       -> Font { .system(size: 13, weight: .medium) }
    static func micro()         -> Font { .system(size: 11, weight: .medium) }
    static func score()         -> Font { .system(size: 56, weight: .black, design: .monospaced) }
    static func scoreMedium()   -> Font { .system(size: 36, weight: .bold, design: .monospaced) }
    static func monoSmall()     -> Font { .system(size: 13, weight: .medium, design: .monospaced) }
}

// MARK: - Spacing

struct SMVSpacing {
    static let xs:   CGFloat = 4
    static let sm:   CGFloat = 8
    static let md:   CGFloat = 12
    static let lg:   CGFloat = 16
    static let xl:   CGFloat = 20
    static let xxl:  CGFloat = 24
    static let xxxl: CGFloat = 32
    static let huge: CGFloat = 48
}

// MARK: - Corner Radii (Sharper)

struct SMVRadius {
    static let sm:   CGFloat = 6
    static let md:   CGFloat = 8
    static let lg:   CGFloat = 12
    static let xl:   CGFloat = 16
    static let full: CGFloat = 999
}

// MARK: - View Modifiers

struct GlassmorphismModifier: ViewModifier {
    var cornerRadius: CGFloat = SMVRadius.lg
    var opacity: Double = 0.04

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.smvSurface1.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.white.opacity(0.04), lineWidth: 0.5)
                    )
            )
    }
}

struct GlowModifier: ViewModifier {
    let color: Color
    var radius: CGFloat = 8

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.2), radius: radius, x: 0, y: 2)
    }
}

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.05), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.6)
                    .offset(x: -geo.size.width * 0.3 + phase * (geo.size.width * 1.6))
                    .mask(content)
                }
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

struct NoiseModifier: ViewModifier {
    var opacity: Double = 0.015

    func body(content: Content) -> some View {
        content
            .overlay(
                Canvas { context, size in
                    // Subtle noise pattern
                    for _ in 0..<Int(size.width * size.height * 0.003) {
                        let x = CGFloat.random(in: 0...size.width)
                        let y = CGFloat.random(in: 0...size.height)
                        let brightness = CGFloat.random(in: 0.3...0.7)
                        context.fill(
                            Path(CGRect(x: x, y: y, width: 1, height: 1)),
                            with: .color(.white.opacity(brightness))
                        )
                    }
                }
                .opacity(opacity)
                .allowsHitTesting(false)
            )
    }
}

extension View {
    func glassmorphism(cornerRadius: CGFloat = SMVRadius.lg, opacity: Double = 0.04) -> some View {
        modifier(GlassmorphismModifier(cornerRadius: cornerRadius, opacity: opacity))
    }

    func glow(_ color: Color, radius: CGFloat = 8) -> some View {
        modifier(GlowModifier(color: color, radius: radius))
    }

    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }

    func noise(opacity: Double = 0.015) -> some View {
        modifier(NoiseModifier(opacity: opacity))
    }
}

