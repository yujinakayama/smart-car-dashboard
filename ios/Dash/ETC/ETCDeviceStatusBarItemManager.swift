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
        NotificationCenter.default.addObserver(forName: .ETCDeviceDidUpdateCurrentCard, object: nil, queue: .main) { [weak self] (notification) in
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
        let label = CardLabel(insets: UIEdgeInsets(top: 4, left: 7, bottom: 4, right: 7))
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

extension ETCDeviceStatusBarItemManager {
    class CardLabel: UILabel {
        let insets: UIEdgeInsets

        var borderColor: UIColor? {
            get {
                return _borderColor
            }

            set {
                _borderColor = newValue
                applyBorderColor()
            }
        }

        private var _borderColor: UIColor?

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

        override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
            super.traitCollectionDidChange(previousTraitCollection)

            if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                applyBorderColor()
            }
        }

        private func applyBorderColor() {
            layer.borderColor = _borderColor?.resolvedColor(with: traitCollection).cgColor
        }
    }
}
