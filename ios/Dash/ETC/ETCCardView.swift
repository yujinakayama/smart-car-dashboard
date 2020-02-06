//
//  ETCCardView.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/02/06.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit

@IBDesignable class ETCCardView: BorderedView {
    // https://www.quora.com/What-are-the-average-dimensions-for-a-credit-card
    let realCardWidth: CGFloat = 85.60
    let realCardHeight: CGFloat = 53.98
    let realCardCornerRadius: CGFloat = (2.88 + 3.48) / 2
    lazy var aspectRatio: CGFloat = realCardWidth / realCardHeight
    lazy var cornerRadiusRatio: CGFloat = realCardCornerRadius / realCardWidth

    override class var requiresConstraintBasedLayout: Bool {
        return true
    }

    @IBInspectable var image: UIImage? {
        get {
            return imageView.image
        }

        set {
            imageView.image = newValue
        }
    }

    @IBInspectable override var cornerRadius: CGFloat {
        get {
            return layer.cornerRadius
        }

        set {
            layer.cornerRadius = newValue
            layer.masksToBounds = newValue > 0
            specifiedCornerRadius = true
        }
    }

    private var specifiedCornerRadius = false

    private var standardCornerRadius: CGFloat {
        return bounds.width * cornerRadiusRatio
    }

    lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    lazy var imageViewMarginConstraints = {
        return [
            imageView.topAnchor.constraint(equalTo: topAnchor, constant: imageViewMargin),
            imageView.leftAnchor.constraint(equalTo: leftAnchor, constant: imageViewMargin),
            bottomAnchor.constraint(equalTo: imageView.bottomAnchor, constant: imageViewMargin),
            rightAnchor.constraint(equalTo: imageView.rightAnchor, constant: imageViewMargin)
        ]
    }()

    required init?(coder: NSCoder) {
        super.init(coder: coder)
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

    func setUp() {
        NSLayoutConstraint.activate([widthAnchor.constraint(equalTo: heightAnchor, multiplier: aspectRatio)])
        addSubview(imageView)
        NSLayoutConstraint.activate(imageViewMarginConstraints)
    }

    override func layoutSubviews() {
        if !specifiedCornerRadius {
            layer.cornerRadius = standardCornerRadius
        }

        for constraint in imageViewMarginConstraints {
            constraint.constant = imageViewMargin
        }

        super.layoutSubviews()
    }

    var imageViewMargin: CGFloat {
        return bounds.width * 0.1
    }
}
