//
//  AppIconImageView.swift
//  DashRemote
//
//  Created by Yuji Nakayama on 2020/02/07.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit

// Not sure why but marking this class as @IBDesignable crashes interface builder agent
class AppIconImageView: UIImageView {
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }

    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        setUp()
    }

    func setUp() {
        layer.masksToBounds = true
        layer.cornerCurve = .continuous
        updateCornerRadius()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateCornerRadius()
    }

    func updateCornerRadius() {
        layer.cornerRadius = bounds.width * 0.18
    }
}
