import Testing
@testable import FarsangUI

struct SpacingTests {
    @Test func providesTheDesignScale() {
        #expect(Spacing.xsmall == 4)
        #expect(Spacing.small == 8)
        #expect(Spacing.medium == 12)
        #expect(Spacing.large == 16)
        #expect(Spacing.xlarge == 24)
        #expect(Spacing.xxlarge == 32)
    }

    @Test func increasesMonotonically() {
        #expect(Spacing.xsmall < Spacing.small)
        #expect(Spacing.small < Spacing.medium)
        #expect(Spacing.medium < Spacing.large)
        #expect(Spacing.large < Spacing.xlarge)
        #expect(Spacing.xlarge < Spacing.xxlarge)
    }
}
