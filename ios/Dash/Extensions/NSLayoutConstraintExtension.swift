//
//  NSLayoutConstraintExtension.swift
//  Dash
//
//  Created by Yuji Nakayama on 2022/02/14.
//  Copyright © 2022 Yuji Nakayama. All rights reserved.
//

import UIKit

extension NSLayoutConstraint {
    func withPriority(_ priority: UILayoutPriority) -> NSLayoutConstraint {
        self.priority = priority
        return self
    }
}
