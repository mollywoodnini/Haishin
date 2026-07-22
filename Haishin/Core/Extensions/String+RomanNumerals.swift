import Foundation

extension String {

    /// Returns a variant with a trailing Arabic number (1-10) replaced by its Roman numeral,
    /// or nil if no such number is found.
    /// - Example: "Saga of Tanya the Evil 2" → "Saga of Tanya the Evil II"
    var romanNumeralVariant: String? {
        let romanMap: [Int: String] = [
            1: "I", 2: "II", 3: "III", 4: "IV", 5: "V",
            6: "VI", 7: "VII", 8: "VIII", 9: "IX", 10: "X"
        ]

        guard let match = self.range(
            of: #"\s+(\d+)$"#,
            options: .regularExpression
        ) else { return nil }

        let numberStr = self[match]
            .trimmingCharacters(in: .whitespaces)

        guard let number = Int(numberStr),
              let roman = romanMap[number]
        else { return nil }

        return self.replacingCharacters(in: match, with: " \(roman)")
    }
}
