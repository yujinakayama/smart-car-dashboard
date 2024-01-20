//
//  UIWindowScene+MultitaskState.swift
//  Dash
//
//  Created by Yuji Nakayama on 2024/01/16.
//  Copyright © 2024 Yuji Nakayama. All rights reserved.
//

import UIKit

enum MultitaskState {
    case fullScreen
    case splittedLarger
    case splittedHalf
    case splittedSmaller
    case slideOver

    var isSplitted: Bool {
        switch self {
        case .splittedLarger, .splittedHalf, .splittedSmaller:
            return true
        default:
            return false
        }
    }
}

fileprivate let separatorMargin: CGFloat = 20

extension UIWindowScene {
    var multitaskState: MultitaskState? {
        guard let window = keyWindow else { return nil }

        let windowWidth = window.bounds.width
        let screenWidth = screen.bounds.width

        if windowWidth == screenWidth {
            return .fullScreen
        } else if abs(windowWidth - (screenWidth / 2)) <= separatorMargin { // Split View has a separator with 10 points
            return .splittedHalf
        } else if windowWidth > screenWidth / 2 {
            return .splittedLarger
        } else {
            if window.bounds.height == screen.bounds.height {
                return .splittedSmaller
            } else {
                return .slideOver
            }
        }
    }
}
