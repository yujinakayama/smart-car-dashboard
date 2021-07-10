//
//  NSRegularExpressionExtension.swift
//  Dash
//
//  Created by Yuji Nakayama on 2021/07/10.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import Foundation

fileprivate func entireRange(of string: String) -> NSRange {
    return NSRange(0..<string.count)
}

extension NSRegularExpression {
    func numberOfMatches(in string: String, options: NSRegularExpression.MatchingOptions = []) -> Int {
        return numberOfMatches(in: string, options: options, range: entireRange(of: string))
    }

    func enumerateMatches(in string: String, options: NSRegularExpression.MatchingOptions = [], using block: (NSTextCheckingResult?, NSRegularExpression.MatchingFlags, UnsafeMutablePointer<ObjCBool>) -> Void) {
        enumerateMatches(in: string, options: options, range: entireRange(of: string), using: block)
    }

    func matches(in string: String, options: NSRegularExpression.MatchingOptions = []) -> [NSTextCheckingResult] {
        return matches(in: string, options: options, range: entireRange(of: string))
    }

    func firstMatch(in string: String, options: NSRegularExpression.MatchingOptions = []) -> NSTextCheckingResult? {
        return firstMatch(in: string, options: options, range: entireRange(of: string))
    }

    func rangeOfFirstMatch(in string: String, options: NSRegularExpression.MatchingOptions = []) -> NSRange {
        return rangeOfFirstMatch(in: string, options: options, range: entireRange(of: string))
    }
}
