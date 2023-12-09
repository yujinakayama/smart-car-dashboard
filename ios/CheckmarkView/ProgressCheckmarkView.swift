//
//  ProgressCheckmarkView.swift
//  CheckmarkView
//
//  Created by Yuji Nakayama on 2023/12/08.
//  Copyright © 2023 Yuji Nakayama. All rights reserved.
//

import UIKit

public class ProgressCheckmarkView: UIView {
    public enum State {
        case inactive
        case inProgress
        case done
    }

    public var state: State = .inactive {
        didSet {
            if state != oldValue {
                update()
            }
        }
    }

    let progressView = ProgressView()
    let checkmarkView = CheckmarkView()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        progressView.translatesAutoresizingMaskIntoConstraints = false
        checkmarkView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(progressView)
        addSubview(checkmarkView)

        NSLayoutConstraint.activate([
            progressView.leftAnchor.constraint(equalTo: leftAnchor),
            progressView.rightAnchor.constraint(equalTo: rightAnchor),
            progressView.topAnchor.constraint(equalTo: topAnchor),
            progressView.bottomAnchor.constraint(equalTo: bottomAnchor),
            checkmarkView.centerXAnchor.constraint(equalTo: centerXAnchor),
            checkmarkView.centerYAnchor.constraint(equalTo: centerYAnchor),
            checkmarkView.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.41),
            checkmarkView.heightAnchor.constraint(equalTo: checkmarkView.widthAnchor)
        ])
    }

    private func update() {
        switch state {
        case .inactive:
            progressView.stopAnimating()
            checkmarkView.clear()
        case .inProgress:
            progressView.startAnimating()
            checkmarkView.clear()
        case .done:
            progressView.stopAnimating()
            checkmarkView.startAnimating()
        }
    }
}
