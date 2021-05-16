//
//  NSLayoutConstraintExtension.swift
//  Dash
//
//  Created by Yuji Nakayama on 2021/05/05.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import UIKit

extension NSLayoutConstraint {
    func withPriority(_ priority: UILayoutPriority) -> NSLayoutConstraint {
        self.priority = priority
        return self
    }
}
