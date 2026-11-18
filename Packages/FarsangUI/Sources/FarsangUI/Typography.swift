import SwiftUI

extension Font {
    /// A rounded system font, the base of Farsang text.
    public static func rounded(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    /// The Farsang metric-number style: a rounded font with tabular
    /// (monospaced) digits so running metrics line up as they change.
    public static func metric(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        rounded(size, weight: weight).monospacedDigit()
    }
}

/// A Farsang type token: a rounded system font whose point size scales with
/// Dynamic Type. `size` is the design size at the default (Large) text size;
/// `relativeTo` picks which accessibility text setting drives the scaling.
/// Read `font` inside a view to get the scaled font; `designFont` returns the
/// unscaled design size for tests and static previews.
public struct ScaledFont: DynamicProperty, Sendable {
    private let baseSize: CGFloat
    @ScaledMetric private var scaledSize: CGFloat
    private let weight: Font.Weight
    private let monospacedDigits: Bool

    public init(
        size: CGFloat,
        weight: Font.Weight = .regular,
        relativeTo style: Font.TextStyle = .body,
        monospacedDigits: Bool = false
    ) {
        baseSize = size
        _scaledSize = ScaledMetric(wrappedValue: size, relativeTo: style)
        self.weight = weight
        self.monospacedDigits = monospacedDigits
    }

    /// The font at the design size, ignoring Dynamic Type.
    public var designFont: Font {
        let base = Font.rounded(baseSize, weight: weight)
        return monospacedDigits ? base.monospacedDigit() : base
    }

    /// The font resolved at the current Dynamic Type size.
    public var font: Font {
        let base = Font.rounded(scaledSize, weight: weight)
        return monospacedDigits ? base.monospacedDigit() : base
    }
}

/// Farsang type sizes, split between the watch and the phone.
public enum Typography {
    // Watch metrics, from `docs/design/watch-v4.html`. These scale with Dynamic
    // Type: each keeps its design size at the default text size and grows or
    // shrinks with the accessibility text setting it is relative to.
    public static let watchHero = ScaledFont(
        size: 40, weight: .bold, relativeTo: .largeTitle, monospacedDigits: true)
    public static let watchLarge = ScaledFont(
        size: 26, weight: .bold, relativeTo: .title2, monospacedDigits: true)
    public static let watchMedium = ScaledFont(
        size: 22, weight: .bold, relativeTo: .title3, monospacedDigits: true)
    public static let watchUnit = ScaledFont(
        size: 12, weight: .semibold, relativeTo: .caption)
    public static let watchLabel = ScaledFont(
        size: 10, weight: .semibold, relativeTo: .caption2)

    // Phone metrics.
    public static let phoneDisplay = Font.metric(64)
    public static let phoneTitle = Font.metric(34)
    public static let phoneHeadline = Font.metric(22)
    public static let phoneBody = Font.rounded(17)
    public static let phoneCaption = Font.rounded(12, weight: .semibold)
}
