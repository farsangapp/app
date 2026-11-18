import SwiftUI

/// A running metric: a dim label over a big tinted number and its unit,
/// matching the metric rows in `docs/design/watch-v4.html`.
public struct MetricView: View {
    public let label: String
    public let value: String
    public let unit: String?
    public let tint: Color

    /// An optional override for the value font. When `nil`, the value uses the
    /// Dynamic Type-scaling `Typography.watchLarge` token.
    public let valueFont: Font?

    private var labelToken = Typography.watchLabel
    private var unitToken = Typography.watchUnit
    private var valueToken = Typography.watchLarge

    public init(
        label: String,
        value: String,
        unit: String? = nil,
        tint: Color = .primary,
        valueFont: Font? = nil
    ) {
        self.label = label
        self.value = value
        self.unit = unit
        self.tint = tint
        self.valueFont = valueFont
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xsmall) {
            Text(label)
                .font(labelToken.font)
                .textCase(.uppercase)
                .foregroundStyle(Palette.dim.color)

            HStack(alignment: .lastTextBaseline, spacing: Spacing.small) {
                Text(value)
                    .font(valueFont ?? valueToken.font)
                    .foregroundStyle(tint)

                if let unit {
                    Text(unit)
                        .font(unitToken.font)
                        .textCase(.uppercase)
                        .foregroundStyle(tint)
                }
            }
        }
    }
}
