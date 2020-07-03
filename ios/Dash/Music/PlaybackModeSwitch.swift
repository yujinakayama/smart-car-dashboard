//
//  PlaybackModeButton.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/07/02.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit

@IBDesignable class PlaybackModeSwitch: UIButton {
    var isOn: Bool = false {
        didSet {
            updateAppearance()
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    func commonInit() {
        layer.cornerRadius = 6

        setPreferredSymbolConfiguration(UIImage.SymbolConfiguration(pointSize: 16), forImageIn: .normal)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 28),
            widthAnchor.constraint(equalTo: heightAnchor)
        ])

        addTarget(self, action: #selector(didTouchUpInside), for: .touchUpInside)
    }

    @objc func didTouchUpInside() {
        isOn = !isOn
        sendActions(for: .valueChanged)
    }

    func updateAppearance() {
        if isOn {
            imageView?.tintColor = .white
            backgroundColor = tintColor
        } else {
            imageView?.tintColor = tintColor
            backgroundColor = nil
        }
    }
}
