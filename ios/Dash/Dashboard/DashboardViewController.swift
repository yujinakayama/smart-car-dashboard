//
//  DashboardViewController.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/11/21.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit

// Container view controller
class DashboardViewController: UIViewController {
    @IBOutlet weak var widgetView: UIView!
    @IBOutlet weak var musicContainerView: UIView!
    @IBOutlet weak var musicEdgeGlossView: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()

        NSLayoutConstraint.activate([
            musicEdgeGlossView.heightAnchor.constraint(equalToConstant: 1.0 / UIScreen.main.scale)
        ])

        updateMusicContainerViewShadow()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateMusicContainerViewShadow()
        }
    }

    private func updateMusicContainerViewShadow() {
        musicContainerView.layer.shadowColor = UIColor.black.cgColor
        musicContainerView.layer.shadowOffset = CGSize.zero
        musicContainerView.layer.shadowRadius = 20

        switch traitCollection.userInterfaceStyle {
        case .dark:
            musicContainerView.layer.shadowOpacity = 0.5
            musicEdgeGlossView.backgroundColor = UIColor(white: 1, alpha: 0.15)
        default:
            musicContainerView.layer.shadowOpacity = 0.15
            musicEdgeGlossView.backgroundColor = .white
        }
    }
}
