import SwiftUI
import Testing
@testable import FarsangUI

struct TypographyTests {
    @Test func metricFontAddsTabularDigits() {
        // The metric variant is exactly the rounded bold font of the same size
        // with the monospaced-digit feature applied.
        #expect(Font.metric(26) == Font.rounded(26, weight: .bold).monospacedDigit())
    }

    @Test func watchSizesAreDistinct() {
        #expect(Typography.watchHero.designFont != Typography.watchLarge.designFont)
        #expect(Typography.watchLarge.designFont != Typography.watchMedium.designFont)
        #expect(Typography.watchHero.designFont != Typography.watchMedium.designFont)
    }
}
