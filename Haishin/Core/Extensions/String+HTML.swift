//
//  String+HTML.swift
//  Haishin
//
//  Created by Haishin on 25.01.26.
//

import Foundation


//#################################################################################
// MARK: - String HTML Decoding Extension
//#################################################################################

extension String {

    //#################################################################################
    // MARK: - Public Methods
    //#################################################################################

    /// Decodes HTML entities in the string.
    /// - Returns: A new string with HTML entities decoded.
    func decodingHTMLEntities() -> String {
        var result = self

        // Named entities
        let namedEntities: [String: String] = [
            "&nbsp;": " ",
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&apos;": "'",
            "&ndash;": "–",
            "&mdash;": "—",
            "&lsquo;": "'",
            "&rsquo;": "'",
            "&ldquo;": "\"",
            "&rdquo;": "\"",
            "&hellip;": "…",
            "&copy;": "©",
            "&reg;": "®",
            "&trade;": "™"
        ]

        for (entity, replacement) in namedEntities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }

        // Numeric entities (decimal): &#039; &#39; &#8217; etc.
        result = decodeNumericEntities(in: result, pattern: #"&#(\d+);"#)

        // Numeric entities (hexadecimal): &#x27; &#x2019; etc.
        result = decodeNumericEntities(in: result, pattern: #"&#[xX]([0-9a-fA-F]+);"#, isHex: true)

        return result
    }


    //#################################################################################
    // MARK: - Private Methods
    //#################################################################################

    private func decodeNumericEntities(in string: String,
                                       pattern: String,
                                       isHex: Bool = false) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return string
        }

        var result = string
        let nsRange = NSRange(result.startIndex..<result.endIndex, in: result)
        let matches = regex.matches(in: result, range: nsRange)

        // Process matches in reverse order to preserve indices
        for match in matches.reversed() {
            guard let codeRange = Range(match.range(at: 1), in: result),
                  let fullRange = Range(match.range, in: result) else {
                continue
            }

            let codeString = String(result[codeRange])
            let codePoint: UInt32?

            if isHex {
                codePoint = UInt32(codeString, radix: 16)
            } else {
                codePoint = UInt32(codeString)
            }

            if let codePoint, let scalar = Unicode.Scalar(codePoint) {
                let character = String(Character(scalar))
                result.replaceSubrange(fullRange, with: character)
            }
        }

        return result
    }
}
