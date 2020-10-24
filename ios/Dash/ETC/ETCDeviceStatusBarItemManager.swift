//
//  ETCDeviceStatusBarItemManager.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/01/19.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit

class ETCDeviceStatusBarItemManager {
    let device: ETCDevice

    weak var navigationItem: UINavigationItem?

    var tintColor: UIColor?

    private lazy var disconnectedStatusBarButtonItem: UIBarButtonItem = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "bolt.slash.fill")
        imageView.tintColor = UIColor(named: "Inactive Bar Item Color")
        imageView.contentMode = .scaleAspectFit
        imageView.heightAnchor.constraint(equalToConstant: 24).isActive = true
        imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor).isActive = true
        return UIBarButtonItem(customView: imageView)
    }()

    init(device: ETCDevice) {
        self.device = device
        startObservingNotifications()
    }

    func addBarItem(to navigationItem: UINavigationItem) {
        self.navigationItem = navigationItem
        updateNavigationItem()
    }

    private func startObservingNotifications() {
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(updateNavigationOnMainThread), name: .ETCDeviceDidConnect, object: device)
        notificationCenter.addObserver(self, selector: #selector(updateNavigationOnMainThread), name: .ETCDeviceDidDisconnect, object: device)
        notificationCenter.addObserver(self, selector: #selector(updateNavigationOnMainThread), name: .ETCDeviceDidDetectCardInsertion, object: device)
        notificationCenter.addObserver(self, selector: #selector(updateNavigationOnMainThread), name: .ETCDeviceDidDetectCardEjection, object: device)
    }

    @objc private func updateNavigationOnMainThread() {
        DispatchQueue.main.async {
            self.updateNavigationItem()
        }
    }

    private func updateNavigationItem() {
        guard let navigationItem = navigationItem else { return }

        if device.isConnected {
            if let card = device.currentCard {
                navigationItem.rightBarButtonItem = makeCardBarButtonItem(for: card.displayedName, color: tintColor)
            } else {
                navigationItem.rightBarButtonItem = makeCardBarButtonItem(for: "No Card", color: UIColor(named: "Inactive Bar Item Color"))
            }
        } else {
            navigationItem.rightBarButtonItem = disconnectedStatusBarButtonItem
        }
    }

    private func makeCardBarButtonItem(for cardName: String, color: UIColor?) -> UIBarButtonItem {
        let label = CardLabel(insets: UIEdgeInsets(top: 3, left: 5, bottom: 3, right: 5))
        label.text = cardName
        label.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .white
        label.backgroundColor = color
        label.layer.cornerRadius = 5
        label.layer.masksToBounds = true

        return UIBarButtonItem(customView: label)
    }
}

extension ETCDeviceStatusBarItemManager {
    class CardLabel: UILabel {
        let insets: UIEdgeInsets

        init(insets: UIEdgeInsets) {
            self.insets = insets
            super.init(frame: CGRect.zero)
        }

        required init?(coder: NSCoder) {
            insets = UIEdgeInsets.zero
            super.init(coder: coder)
        }

        override func drawText(in rect: CGRect) {
            super.drawText(in: rect.inset(by: insets))
        }

        override var intrinsicContentSize: CGSize {
            var size = super.intrinsicContentSize
            size.height += insets.top + insets.bottom
            size.width += insets.left + insets.right
            return size
        }

        override func sizeThatFits(_ size: CGSize) -> CGSize {
            var fittingSize = super.sizeThatFits(size)
            fittingSize.width = fittingSize.width + insets.left + insets.right
            fittingSize.height = fittingSize.height + insets.top + insets.bottom
            return fittingSize
        }
    }
}
