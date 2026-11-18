import Foundation

public enum DistanceFormatter {
    private static let numberLocale = Locale(identifier: "en_US_POSIX")

    public static func string(fromMeters meters: Double, unitSystem: UnitSystem) -> String {
        let value = unitSystem.value(fromMeters: meters)
        let number = String(format: "%.2f", locale: Self.numberLocale, value)
        return "\(number) \(unitSystem.unitSymbol)"
    }
}
