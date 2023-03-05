//
//  ETCCardView.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/02/06.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit

@IBDesignable class ETCCardView: UIView {
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

    @IBInspectable var cornerRadius: CGFloat {
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

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    func commonInit() {
        addSubview(imageView)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalTo: heightAnchor, multiplier: aspectRatio),
            imageView.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.8),
            imageView.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.8),
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        if !specifiedCornerRadius {
            layer.cornerRadius = standardCornerRadius
        }
    }
}
