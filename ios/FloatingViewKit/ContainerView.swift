//
//  ContainerView.swift
//  FloatingViewKit
//
//  Created by Yuji Nakayama on 2023/07/29.
//  Copyright © 2023 Yuji Nakayama. All rights reserved.
//

import UIKit

class ContainerView: UIView {
    // https://khanlou.com/2018/09/hacking-hit-tests/
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard isUserInteractionEnabled,
              !isHidden,
              alpha >= 0.01,
              self.point(inside: point, with: event)
        else { return nil }

        for subview in subviews {
            guard subview is FloatingView else {
                continue
            }

            let convertedPoint = subview.convert(point, from: self)
            if let eventReceiver = subview.hitTest(convertedPoint, with: event) {
                return eventReceiver
            }
        }

        // Ignore event to ContainerView itself
        return nil
    }
}
