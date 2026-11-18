import SwiftUI
import Testing
@testable import FarsangUI

@MainActor
struct MetricViewTests {
    @Test func storesLabelValueUnitAndTint() {
        let view = MetricView(
            label: "Distance",
            value: "6.21",
            unit: "km",
            tint: Palette.green.color
        )

        #expect(view.label == "Distance")
        #expect(view.value == "6.21")
        #expect(view.unit == "km")
        #expect(view.tint == Palette.green.color)
    }

    @Test func unitDefaultsToNil() {
        let view = MetricView(label: "Time", value: "32:18")
        #expect(view.unit == nil)
    }
}
