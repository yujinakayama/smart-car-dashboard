//
//  BorderedButton.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/01/28.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit
import TransitionButton

@IBDesignable class FloatButton: TransitionButton {
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setUp()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }

    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        setUp()
    }

    func setUp(){
        normalBackgroundColor = backgroundColor
    }

    private var normalBackgroundColor: UIColor?

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.masksToBounds = false
    }

    override func stopAnimation(animationStyle: StopAnimationStyle = .normal, revertAfterDelay delay: TimeInterval = 1.0, completion: (() -> Void)? = nil) {
        if animationStyle == .expand {
            // Disable shadow in the expansion animation since it slows down the animation
            let originalShadowOpacity = layer.shadowOpacity
            layer.shadowOpacity = 0

            super.stopAnimation(animationStyle: animationStyle, revertAfterDelay: delay) {
                self.layer.shadowOpacity = originalShadowOpacity
                if let completion = completion {
                    completion()
                }
            }
        } else {
            super.stopAnimation(animationStyle: animationStyle, revertAfterDelay: delay, completion: completion)
        }
    }

    @IBInspectable var highlightedBackgroundColor: UIColor?

    override var isHighlighted: Bool {
        didSet {
            if isHighlighted {
                backgroundColor = highlightedBackgroundColor
            } else {
                backgroundColor = normalBackgroundColor
            }
        }
    }

    @IBInspectable var isContinuousCornerCurve: Bool {
        get {
            return layer.cornerCurve == .continuous
        }

        set {
            layer.cornerCurve = newValue ? .continuous : .circular
        }
    }

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

    @IBInspectable var shadowRadius: CGFloat {
        get {
            return layer.shadowRadius
        }

        set {
            layer.shadowRadius = newValue
        }
    }

    @IBInspectable var shadowOpacity: Float {
        get {
            return layer.shadowOpacity
        }

        set {
            layer.shadowOpacity = newValue
        }
    }

    @IBInspectable var shadowOffset: CGSize {
        get {
            return layer.shadowOffset
        }

        set {
            layer.shadowOffset = newValue
        }
    }

    @IBInspectable var shadowColor: UIColor? {
        get {
            return _shadowColor
        }

        set {
            _shadowColor = newValue
            applyShadowColor()
        }
    }

    private var _shadowColor: UIColor?

    private func applyShadowColor() {
        layer.shadowColor = _shadowColor?.resolvedColor(with: traitCollection).cgColor
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            applyBorderColor()
            applyShadowColor()
        }
    }
}
