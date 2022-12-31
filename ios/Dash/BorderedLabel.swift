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

    @IBInspectable var topInset: CGFloat = 0 {
        didSet {
            invalidateIntrinsicContentSize()
        }
    }

    @IBInspectable var leftInset: CGFloat = 0 {
        didSet {
            invalidateIntrinsicContentSize()
        }
    }

    @IBInspectable var bottomInset: CGFloat = 0 {
        didSet {
            invalidateIntrinsicContentSize()
        }
    }

    @IBInspectable var rightInset: CGFloat = 0 {
        didSet {
            invalidateIntrinsicContentSize()
        }
    }

    var insets: UIEdgeInsets {
        get {
            return UIEdgeInsets(top: topInset, left: leftInset, bottom: bottomInset, right: rightInset)
        }

        set {
            topInset = newValue.top
            leftInset = newValue.left
            bottomInset = newValue.bottom
            rightInset = newValue.right
        }
    }

    init(insets: UIEdgeInsets) {
        super.init(frame: CGRect.zero)
        self.insets = insets
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let contentSize = super.intrinsicContentSize

        return CGSize(
            width: contentSize.width + insets.left + insets.right,
            height: contentSize.height + insets.top + insets.bottom
        )
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        var fittingSize = super.sizeThatFits(size)
        fittingSize.width = fittingSize.width + insets.left + insets.right
        fittingSize.height = fittingSize.height + insets.top + insets.bottom
        return fittingSize
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            applyBorderColor()
        }
    }
}
