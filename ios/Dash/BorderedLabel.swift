//
//  BorderedLabel.swift
//  Dash
//
//  Created by Yuji Nakayama on 2021/06/21.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import UIKit

@IBDesignable class BorderedLabel: UILabel {
    @IBInspectable var borderColor: UIColor? {
        get {
            return _borderColor
        }

        set {
            _borderColor = newValue
            applyBorderColor()
        }
    }

    private var _borderColor: UIColor?

    private func applyBorderColor() {
        layer.borderColor = _borderColor?.resolvedColor(with: traitCollection).cgColor
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

    @IBInspectable var topPaddingInset: CGFloat = 0 {
        didSet {
            invalidateIntrinsicContentSize()
        }
    }

    @IBInspectable var leftPaddingInset: CGFloat = 0 {
        didSet {
            invalidateIntrinsicContentSize()
        }
    }

    @IBInspectable var bottomPaddingInset: CGFloat = 0 {
        didSet {
            invalidateIntrinsicContentSize()
        }
    }

    @IBInspectable var rightPaddingInset: CGFloat = 0 {
        didSet {
            invalidateIntrinsicContentSize()
        }
    }

    var paddingInset: UIEdgeInsets {
        return UIEdgeInsets(top: topPaddingInset, left: leftPaddingInset, bottom: bottomPaddingInset, right: rightPaddingInset)
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: paddingInset))
    }

    override var intrinsicContentSize: CGSize {
        let contentSize = super.intrinsicContentSize

        return CGSize(
            width: contentSize.width + paddingInset.left + paddingInset.right,
            height: contentSize.height + paddingInset.top + paddingInset.bottom
        )
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            applyBorderColor()
        }
    }
}
