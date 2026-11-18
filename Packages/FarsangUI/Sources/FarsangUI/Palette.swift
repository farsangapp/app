import SwiftUI

/// An 8-bit RGB color, expressed as a 24-bit hex value. This is the palette's
/// single source of truth: it is testable without a rendering context and
/// converts to a SwiftUI `Color` when a view needs one.
public struct RGB: Sendable, Hashable {
    /// The color as `0xRRGGBB`.
    public let hex: UInt32

    public init(hex: UInt32) {
        self.hex = hex
    }

    /// The red component in `0...1`.
    public var red: Double { Double((hex >> 16) & 0xff) / 255 }

    /// The green component in `0...1`.
    public var green: Double { Double((hex >> 8) & 0xff) / 255 }

    /// The blue component in `0...1`.
    public var blue: Double { Double(hex & 0xff) / 255 }

    /// The SwiftUI `Color`.
    public var color: Color {
        Color(red: red, green: green, blue: blue)
    }
}

/// The Farsang palette, sourced from the `:root` variables and watch frame in
/// `docs/design/watch-v4.html`.
public enum Palette {
    /// True black: the dark OLED background behind every screen.
    public static let background = RGB(hex: 0x000000)

    /// Amber: the route and elapsed time.
    public static let amber = RGB(hex: 0xffb627)

    /// Cyan: the user marker and pace.
    public static let cyan = RGB(hex: 0x35d0ff)

    /// Green (the design's "mint"): distance.
    public static let green = RGB(hex: 0x32d583)

    /// Red: heart rate and off-route warnings.
    public static let red = RGB(hex: 0xff453a)

    /// Blue: heart-rate zone fills.
    public static let blue = RGB(hex: 0x4da3ff)

    /// Primary text.
    public static let ink = RGB(hex: 0xf4f5f6)

    /// Dim secondary text and unit labels.
    public static let dim = RGB(hex: 0x8b949c)

    /// Card and control backgrounds.
    public static let card = RGB(hex: 0x14181c)
}
