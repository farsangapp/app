import Foundation

/// Parses the ISO 8601 timestamps GPX uses, with or without fractional seconds and with a `Z` or numeric offset.
///
/// `ISO8601DateFormatter` costs tens of microseconds per call, which adds up over a 50,000-point file.
/// Timestamps in the common UTC form (`2025-01-01T08:00:00Z`, optionally with fractional seconds) are decoded by
/// hand; timestamps with a numeric offset go through the formatter.
struct GPXTimeParser {
    private let plain = ISO8601DateFormatter()
    private let fractional = ISO8601DateFormatter()

    init() {
        plain.formatOptions = [.withInternetDateTime]
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    func parse(_ string: String) -> Date? {
        if string.hasSuffix("Z") { return parseUTC(string) }
        // The formatter normalizes impossible dates such as February 29 in a common year, so check the date first.
        guard hasValidCalendarDate(string) else { return nil }
        return plain.date(from: string) ?? fractional.date(from: string)
    }

    private static let digits = UInt8(ascii: "0")...UInt8(ascii: "9")

    /// Whether the `YYYY-MM-DD` start of `string` names a real day. Strings too short or oddly shaped pass
    /// through to the formatter, which rejects them.
    private func hasValidCalendarDate(_ string: String) -> Bool {
        let bytes = Array(string.utf8.prefix(10))
        guard bytes.count == 10, bytes[4] == UInt8(ascii: "-"), bytes[7] == UInt8(ascii: "-") else { return true }
        let digitBytes = bytes[0..<4] + bytes[5..<7] + bytes[8..<10]
        guard digitBytes.allSatisfy(Self.digits.contains) else { return true }
        let value = { (range: Range<Int>) in bytes[range].reduce(0) { $0 * 10 + Int($1 - UInt8(ascii: "0")) } }
        return Self.isValidDay(year: value(0..<4), month: value(5..<7), day: value(8..<10))
    }

    private static func isValidDay(year: Int, month: Int, day: Int) -> Bool {
        guard year >= 1, (1...12).contains(month) else { return false }
        let isLeapYear = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
        let daysInMonth = [31, isLeapYear ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][month - 1]
        return (1...daysInMonth).contains(day)
    }

    /// Decodes `YYYY-MM-DDTHH:MM:SS[.fraction]Z`, or returns `nil` for any other shape or an invalid date.
    private func parseUTC(_ string: String) -> Date? {
        var bytes = Array(string.utf8)
        guard bytes.count >= 20, bytes.removeLast() == UInt8(ascii: "Z") else { return nil }

        /// The decimal value of the digits in `range`, or `nil` if any is not an ASCII digit.
        /// With `accumulate` false only the digits are checked, and the result is 0.
        func number(_ range: Range<Int>, accumulate: Bool = true) -> Int? {
            var value = 0
            for byte in bytes[range] {
                guard Self.digits.contains(byte) else { return nil }
                if accumulate { value = value * 10 + Int(byte - UInt8(ascii: "0")) }
            }
            return value
        }

        guard
            bytes[4] == UInt8(ascii: "-"), bytes[7] == UInt8(ascii: "-"), bytes[10] == UInt8(ascii: "T"),
            bytes[13] == UInt8(ascii: ":"), bytes[16] == UInt8(ascii: ":"),
            let year = number(0..<4), let month = number(5..<7), let day = number(8..<10),
            let hour = number(11..<13), let minute = number(14..<16), let second = number(17..<19),
            hour <= 24, minute < 60, second < 61, Self.isValidDay(year: year, month: month, day: day)
        else { return nil }

        var fraction = 0.0
        var fractionIsZero = true
        if bytes.count > 19 {
            guard bytes[19] == UInt8(ascii: "."), bytes.count > 20 else { return nil }
            // Every digit must be valid, but nanosecond precision is plenty: extra digits are not used,
            // so the value cannot overflow.
            guard number(20..<bytes.count, accumulate: false) != nil else { return nil }
            let end = min(bytes.count, 29)
            fraction = Double(number(20..<end) ?? 0) / pow(10, Double(end - 20))
            fractionIsZero = bytes[20...].allSatisfy { $0 == UInt8(ascii: "0") }
        }

        // `24:00:00` is the xsd:dateTime end-of-day form of midnight on the next day; nothing later is valid.
        let isEndOfDay = hour == 24
        if isEndOfDay, minute != 0 || second != 0 || !fractionIsZero { return nil }

        // Days since 1970-01-01 in the proleptic Gregorian calendar (Howard Hinnant's algorithm).
        let shiftedYear = month <= 2 ? year - 1 : year
        let era = shiftedYear / 400
        let yearOfEra = shiftedYear - era * 400
        let monthIndex = (month + 9) % 12
        let dayOfYear = (153 * monthIndex + 2) / 5 + day - 1
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        // Widen before scaling: `Int` is 32 bits on arm64_32, where days * 86,400 overflows after 2038.
        let days = Int64(era * 146_097 + dayOfEra - 719_468) + (isEndOfDay ? 1 : 0)
        let wholeSeconds = days * 86_400 + Int64((isEndOfDay ? 0 : hour) * 3_600 + minute * 60 + second)
        return Date(timeIntervalSince1970: Double(wholeSeconds) + fraction)
    }
}
