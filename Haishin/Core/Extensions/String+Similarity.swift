//
//  String+Similarity.swift
//  Haishin
//
//  Created by Tan Nghia La on 25.01.26.
//

import Foundation


//#################################################################################
// MARK: - String Similarity Extension
//#################################################################################

extension String {

    //#################################################################################
    // MARK: - Public Methods
    //#################################################################################

    /// Calculates the similarity score between this string and another string.
    /// Uses a combination of word overlap and normalized Levenshtein distance.
    /// - Parameter other: The string to compare against.
    /// - Returns: A score between 0.0 (no similarity) and 1.0 (identical).
    func similarityScore(to other: String) -> Double {
        let normalizedSelf = normalizedForComparison()
        let normalizedOther = other.normalizedForComparison()

        // If exact match after normalization, return perfect score
        if normalizedSelf == normalizedOther {
            return 1.0
        }

        // Calculate word-based Jaccard similarity (handles word reordering)
        let wordSimilarity = jaccardSimilarity(to: other)

        // Calculate character-level similarity using Levenshtein
        let levenshteinSimilarity = normalizedLevenshteinSimilarity(to: other)

        // Weight word similarity higher as it handles anime title variations better
        return (wordSimilarity * 0.6) + (levenshteinSimilarity * 0.4)
    }

    /// Calculates the Jaccard similarity coefficient based on word overlap.
    /// - Parameter other: The string to compare against.
    /// - Returns: A score between 0.0 and 1.0.
    func jaccardSimilarity(to other: String) -> Double {
        let selfWords = Set(extractWords())
        let otherWords = Set(other.extractWords())

        guard !selfWords.isEmpty || !otherWords.isEmpty else {
            return 1.0 // Both empty = identical
        }

        let intersection = selfWords.intersection(otherWords)
        let union = selfWords.union(otherWords)

        return Double(intersection.count) / Double(union.count)
    }


    //#################################################################################
    // MARK: - Private Methods
    //#################################################################################

    private func normalizedLevenshteinSimilarity(to other: String) -> Double {
        let normalizedSelf = normalizedForComparison()
        let normalizedOther = other.normalizedForComparison()

        let maxLength = max(normalizedSelf.count, normalizedOther.count)
        guard maxLength > 0 else { return 1.0 }

        let distance = normalizedSelf.levenshteinDistance(to: normalizedOther)
        return 1.0 - (Double(distance) / Double(maxLength))
    }

    private func normalizedForComparison() -> String {
        lowercased()
            .replacingOccurrences(of: "season", with: "")
            .replacingOccurrences(of: "part", with: "")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined(separator: " ")
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func extractWords() -> [String] {
        lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && $0.count > 1 }
    }

    private func levenshteinDistance(to other: String) -> Int {
        let selfChars = Array(self)
        let otherChars = Array(other)
        let m = selfChars.count
        let n = otherChars.count

        if m == 0 { return n }
        if n == 0 { return m }

        var matrix = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: m + 1)

        for i in 0...m { matrix[i][0] = i }
        for j in 0...n { matrix[0][j] = j }

        for i in 1...m {
            for j in 1...n {
                let cost = selfChars[i - 1] == otherChars[j - 1] ? 0 : 1
                matrix[i][j] = Swift.min(matrix[i - 1][j] + 1,
                                         matrix[i][j - 1] + 1,
                                         matrix[i - 1][j - 1] + cost)
            }
        }

        return matrix[m][n]
    }
}
