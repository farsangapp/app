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

/// Farsang type sizes, split between the watch and the phone.
public enum Typography {
    // Watch metrics, from `docs/design/watch-v4.html`.
    public static let watchHero = Font.metric(40)
    public static let watchLarge = Font.metric(26)
    public static let watchMedium = Font.metric(22)
    public static let watchUnit = Font.rounded(12, weight: .semibold)
    public static let watchLabel = Font.rounded(10, weight: .semibold)

    // Phone metrics.
    public static let phoneDisplay = Font.metric(64)
    public static let phoneTitle = Font.metric(34)
    public static let phoneHeadline = Font.metric(22)
    public static let phoneBody = Font.rounded(17)
    public static let phoneCaption = Font.rounded(12, weight: .semibold)
}
