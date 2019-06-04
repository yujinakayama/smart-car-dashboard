//
//  UIViewExtension.swift
//  ETC
//
//  Created by Yuji Nakayama on 2019/06/08.
//  Copyright © 2019 Yuji Nakayama. All rights reserved.
//

import UIKit

extension UIView {
    @IBInspectable var cornerRadius: CGFloat {
        get {
            return layer.cornerRadius
        }

        set {
            layer.cornerRadius = newValue
            layer.masksToBounds = newValue > 0
        }
    }
}
