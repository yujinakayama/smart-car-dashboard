//
//  ETCDeviceStatusBarItemManager.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/01/19.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit

class ETCDeviceStatusBarItemManager {
    let deviceManager: ETCDeviceManager

    weak var navigationItem: UINavigationItem?

    private lazy var disconnectedStatusBarButtonItem: UIBarButtonItem = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "bolt.slash.fill")
        imageView.tintColor = UIColor(named: "Inactive Bar Item Color")
        imageView.contentMode = .scaleAspectFit
        imageView.heightAnchor.constraint(equalToConstant: 24).isActive = true
        imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor).isActive = true
        return UIBarButtonItem(customView: imageView)
    }()

    init(deviceManager: ETCDeviceManager) {
        self.deviceManager = deviceManager
        startObservingCurrentCard()
    }

    func addBarItem(to navigationItem: UINavigationItem) {
        self.navigationItem = navigationItem
        updateNavigationItem()
    }

    private func startObservingCurrentCard() {
        NotificationCenter.default.addObserver(forName: .ETCDeviceManagerDidUpdateCurrentCard, object: nil, queue: .main) { [weak self] (notification) in
            self?.updateNavigationItem()
        }
    }

    private func updateNavigationItem() {
        guard let navigationItem = navigationItem else { return }

        if deviceManager.isConnected {
            if let card = deviceManager.currentCard {
                navigationItem.rightBarButtonItem = makeCardBarButtonItem(for: card.displayedName, color: .secondaryLabel)
            } else {
                navigationItem.rightBarButtonItem = makeCardBarButtonItem(for: String(localized: "No Card"), color: .systemRed)
            }
        } else {
            navigationItem.rightBarButtonItem = disconnectedStatusBarButtonItem
        }
    }

    private func makeCardBarButtonItem(for cardName: String, color: UIColor?) -> UIBarButtonItem {
        let label = BorderedLabel(insets: UIEdgeInsets(top: 4, left: 7, bottom: 4, right: 7))
        label.text = cardName
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = color
        label.borderColor = color
        label.layer.borderWidth = 1
        label.layer.cornerRadius = 6
        label.layer.masksToBounds = true

        return UIBarButtonItem(customView: label)
    }
}
