import SwiftUI

/// A running metric: a dim label over a big tinted number and its unit,
/// matching the metric rows in `docs/design/watch-v4.html`.
public struct MetricView: View {
    public let label: String
    public let value: String
    public let unit: String?
    public let tint: Color
    public let valueFont: Font

    public init(
        label: String,
        value: String,
        unit: String? = nil,
        tint: Color = .primary,
        valueFont: Font = Typography.watchLarge
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
                .font(Typography.watchLabel)
                .textCase(.uppercase)
                .foregroundStyle(Palette.dim.color)

            HStack(alignment: .lastTextBaseline, spacing: Spacing.small) {
                Text(value)
                    .font(valueFont)
                    .foregroundStyle(tint)

                if let unit {
                    Text(unit)
                        .font(Typography.watchUnit)
                        .textCase(.uppercase)
                        .foregroundStyle(tint)
                }
            }
        }
    }
}
