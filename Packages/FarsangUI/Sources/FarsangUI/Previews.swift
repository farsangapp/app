import SwiftUI

// A preview gallery for each token: palette, typography, spacing and MetricView.

private struct Swatch: Identifiable {
    let name: String
    let hex: String
    let color: Color

    var id: String { name }
}

private struct PaletteGallery: View {
    private let swatches: [Swatch] = [
        Swatch(name: "background", hex: "#000000", color: Palette.background.color),
        Swatch(name: "amber", hex: "#ffb627", color: Palette.amber.color),
        Swatch(name: "cyan", hex: "#35d0ff", color: Palette.cyan.color),
        Swatch(name: "green", hex: "#32d583", color: Palette.green.color),
        Swatch(name: "red", hex: "#ff453a", color: Palette.red.color),
        Swatch(name: "blue", hex: "#4da3ff", color: Palette.blue.color),
        Swatch(name: "ink", hex: "#f4f5f6", color: Palette.ink.color),
        Swatch(name: "dim", hex: "#8b949c", color: Palette.dim.color),
        Swatch(name: "card", hex: "#14181c", color: Palette.card.color)
    ]

    var body: some View {
        List(swatches) { swatch in
            HStack(spacing: Spacing.medium) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(swatch.color)
                    .frame(width: 44, height: 44)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Palette.dim.color.opacity(0.4))
                    }
                Text(swatch.name)
                    .font(Typography.phoneHeadline)
                Spacer()
                Text(swatch.hex)
                    .font(Typography.phoneCaption)
                    .foregroundStyle(Palette.dim.color)
            }
            .padding(.vertical, Spacing.xsmall)
        }
    }
}

private struct TypographyGallery: View {
    private let samples: [(name: String, font: Font)] = [
        ("watchHero 40", Typography.watchHero),
        ("watchLarge 26", Typography.watchLarge),
        ("watchMedium 22", Typography.watchMedium),
        ("watchUnit 12", Typography.watchUnit),
        ("watchLabel 10", Typography.watchLabel),
        ("phoneDisplay 64", Typography.phoneDisplay),
        ("phoneTitle 34", Typography.phoneTitle),
        ("phoneHeadline 22", Typography.phoneHeadline),
        ("phoneBody 17", Typography.phoneBody),
        ("phoneCaption 12", Typography.phoneCaption)
    ]

    var body: some View {
        List(samples, id: \.name) { sample in
            VStack(alignment: .leading, spacing: Spacing.xsmall) {
                Text(sample.name)
                    .font(Typography.phoneCaption)
                    .foregroundStyle(Palette.dim.color)
                Text("5:12 6.21 148")
                    .font(sample.font)
            }
            .padding(.vertical, Spacing.xsmall)
        }
    }
}

private struct SpacingGallery: View {
    private let steps: [(name: String, value: CGFloat)] = [
        ("xsmall", Spacing.xsmall),
        ("small", Spacing.small),
        ("medium", Spacing.medium),
        ("large", Spacing.large),
        ("xlarge", Spacing.xlarge),
        ("xxlarge", Spacing.xxlarge)
    ]

    var body: some View {
        List(steps, id: \.name) { step in
            HStack(spacing: Spacing.medium) {
                Text(step.name)
                    .font(Typography.phoneCaption)
                    .frame(width: 64, alignment: .leading)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Palette.amber.color)
                    .frame(width: step.value * 4, height: 12)
                Text("\(Int(step.value))pt")
                    .font(Typography.phoneCaption)
                    .foregroundStyle(Palette.dim.color)
                Spacer()
            }
        }
    }
}

private struct MetricGallery: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.large) {
                MetricView(label: "Time", value: "32:18", tint: Palette.amber.color)
                MetricView(label: "Distance", value: "6.21", unit: "km", tint: Palette.green.color)
                MetricView(label: "Avg pace", value: "5:12", unit: "/km", tint: Palette.cyan.color)
                MetricView(label: "Heart rate", value: "148", unit: "bpm", tint: Palette.red.color)
            }
            .padding()
        }
        .background(Palette.background.color)
    }
}

#Preview("Palette") {
    PaletteGallery()
}

#Preview("Typography") {
    TypographyGallery()
}

#Preview("Spacing") {
    SpacingGallery()
}

#Preview("MetricView") {
    MetricGallery()
}
