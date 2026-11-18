import SwiftUI
import Testing
@testable import FarsangUI

struct TypographyTests {
    @Test func metricFontAddsTabularDigits() {
        // The metric variant differs from the plain rounded font of the same
        // size and weight: it carries the monospaced-digit feature.
        #expect(Font.metric(26) != Font.rounded(26, weight: .bold))
    }

    @Test func watchSizesAreDistinct() {
        #expect(Typography.watchHero != Typography.watchLarge)
        #expect(Typography.watchLarge != Typography.watchMedium)
    }
}
