//
//  UITableViewCellExtension.swift
//  ETC
//
//  Created by Yuji Nakayama on 2019/06/10.
//  Copyright © 2019 Yuji Nakayama. All rights reserved.
//

import UIKit

extension UITableViewCell {
    @IBInspectable var selectedBackgroundColor: UIColor? {
        get {
            return selectedBackgroundView?.backgroundColor
        }

        set {
            let view = UIView()
            view.backgroundColor = newValue
            selectedBackgroundView = view
        }
    }
}
