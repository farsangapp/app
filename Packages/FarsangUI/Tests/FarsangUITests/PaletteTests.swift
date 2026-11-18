import Testing
@testable import FarsangUI

struct PaletteTests {
    @Test func matchesTheDesignHexValues() {
        // Source of truth: `:root` in docs/design/watch-v4.html, plus the
        // watch frame's `background: #000`.
        #expect(Palette.background.hex == 0x000000)
        #expect(Palette.amber.hex == 0xffb627)
        #expect(Palette.cyan.hex == 0x35d0ff)
        #expect(Palette.green.hex == 0x32d583)
        #expect(Palette.red.hex == 0xff453a)
        #expect(Palette.blue.hex == 0x4da3ff)
        #expect(Palette.ink.hex == 0xf4f5f6)
        #expect(Palette.dim.hex == 0x8b949c)
        #expect(Palette.card.hex == 0x14181c)
    }

    @Test func extractsComponentsFromHex() {
        let amber = RGB(hex: 0xffb627)
        #expect(abs(amber.red - 1.0) < 1e-12)
        #expect(abs(amber.green - (182.0 / 255.0)) < 1e-12)
        #expect(abs(amber.blue - (39.0 / 255.0)) < 1e-12)
    }

    @Test func masksHexTo24Bits() {
        // Higher bits are dropped so values with the same channels compare equal.
        #expect(RGB(hex: 0xFF32_D583) == RGB(hex: 0x0032_D583))
    }

    @Test func blackAndWhiteAreExtrema() {
        #expect(RGB(hex: 0x000000).red == 0)
        #expect(RGB(hex: 0x000000).green == 0)
        #expect(RGB(hex: 0x000000).blue == 0)
        #expect(RGB(hex: 0xffffff).red == 1)
        #expect(RGB(hex: 0xffffff).green == 1)
        #expect(RGB(hex: 0xffffff).blue == 1)
    }
}
