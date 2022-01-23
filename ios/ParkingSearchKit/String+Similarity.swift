//
//  StringExtension.swift
//  ParkingSearchKit
//
//  Created by Yuji Nakayama on 2022/01/25.
//  Copyright © 2022 Yuji Nakayama. All rights reserved.
//

import Foundation

extension String {
    func similarity(to other: String) -> Double {
        return jaroSimilarity(Array(self), Array(other))
    }
}

// https://gist.github.com/nicklockwood/27f45d8e8710bc53ad1fbbdfbeb7c68f
fileprivate func jaroSimilarity(_ s1: [Character], _ s2: [Character]) -> Double {
    // If the Strings are equal
    if s1 == s2 {
        return 1
    }

    // Lengths
    let len1 = s1.count
    let len2 = s2.count

    // Maximum distance up to which matching is allowed
    let maxDist = Int(Double(max(len1, len2) / 2) - 1)

    // Number of matches
    var matches = 0.0

    // Hash for matches
    var hash1 = [Int](repeating: 0, count: len1)
    var hash2 = [Int](repeating: 0, count: len2)

    // Traverse through the first String
    for i in 0 ..< len1 {
        // Check for matches
        let start = max(0, i - maxDist)
        for j in start ..< max(start, min(len2, i + maxDist + 1)) {
            // If there is a match
            if s1[i] == s2[j], hash2[j] == 0 {
                hash1[i] = 1
                hash2[j] = 1
                matches += 1
                break
            }
        }
    }

    // If there is no match
    if matches == 0 {
        return 0
    }

    // Number of transpositions
    var t = 0.0

    // Count number of occurances where two characters match but
    // there is a third matched character in between the indices
    var j = 0
    for i in 0 ..< len1 where hash1[i] == 1 {
        // Find the next matched character
        // in second String
        while hash2[j] == 0 {
            j += 1
        }

        if s1[i] != s2[j] {
            j += 1
            t += 1
        }
    }

    // Return the Jaro Similarity
    return (matches / Double(len1) + matches / Double(len2) + (matches - t / 2) / matches) / 3
}
