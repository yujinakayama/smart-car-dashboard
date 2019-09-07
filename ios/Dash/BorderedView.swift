//
//  BorderedView.swift
//  Dash
//
//  Created by Yuji Nakayama on 2019/09/07.
//  Copyright © 2019 Yuji Nakayama. All rights reserved.
//
import UIKit

class BorderedView: UIView {
    @IBInspectable var borderColor: UIColor? {
        get {
            return _borderColor
        }

        set {
            _borderColor = newValue
            applyBorderColor()
        }
    }

    @IBInspectable var borderWidth: CGFloat {
        get {
            return layer.borderWidth
        }

        set {
            layer.borderWidth = newValue
        }
    }

    @IBInspectable var cornerRadius: CGFloat {
        get {
            return layer.cornerRadius
        }

        set {
            layer.cornerRadius = newValue
            layer.masksToBounds = newValue > 0
        }
    }

    private var _borderColor: UIColor?

    private func applyBorderColor() {
        layer.borderColor = _borderColor?.resolvedColor(with: traitCollection).cgColor
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            applyBorderColor()
        }
    }
}
