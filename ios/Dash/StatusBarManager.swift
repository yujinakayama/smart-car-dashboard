//
//  StatusBarManager.swift
//  Dash
//
//  Created by Yuji Nakayama on 2024/01/16.
//  Copyright © 2024 Yuji Nakayama. All rights reserved.
//

import UIKit

extension Notification.Name {
    static let StatusBarManagerDidUpdateVisibility = Notification.Name("StatusBarManagerDidUpdateVisibility")

    // UIKit changes status bar style by UIViewController.preferredStatusBarStyle,
    // but our AdditionalStatusBarManager has no way to get notified of it.
    // So our view controllers overriding preferredStatusBarStyle should post this notification
    // in viewWillAppear() and viewDidDisappear.
    static let StatusBarDidUpdateAppearance = Notification.Name("StatusBarDidUpdateAppearance")
}

class StatusBarManager {
    let windowScene: UIWindowScene

    var rightItems: [StatusBarItem] = [] {
        didSet {
            applyItems()
        }
    }

    private lazy var itemStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .fill
        stackView.distribution = .equalSpacing
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    init(windowScene: UIWindowScene) {
        self.windowScene = windowScene

        update()

        NotificationCenter.default.addObserver(forName: .StatusBarDidUpdateAppearance, object: nil, queue: .main) { [weak self] (notification) in
            guard let self = self else { return }

            // Because UIKit calls view controller's preferredStatusBarStyle after its viewDidAppear/Disappear invocation
            // and the notification is posted from there,
            // we need to wait a tick to the preferredStatusBarStyle is reflected to statusBarManager.statusBarStyle.
            DispatchQueue.main.async {
                self.updateStyle()
            }
        }
    }

    private func applyItems() {
        for view in itemStackView.arrangedSubviews {
            view.removeFromSuperview()
        }

        for item in rightItems {
            let view = StatusBarItemView(item: item)
            itemStackView.addArrangedSubview(view)
        }
    }

    func update() {
        updateStyle()
        updateVisibility()
    }

    private func updateStyle() {
        guard let statusBarManager = windowScene.statusBarManager else { return }

        switch statusBarManager.statusBarStyle {
        case .lightContent:
            itemStackView.overrideUserInterfaceStyle = .dark
        case .darkContent:
            itemStackView.overrideUserInterfaceStyle = .light
        default:
            switch windowScene.traitCollection.userInterfaceStyle {
            case .dark:
                itemStackView.overrideUserInterfaceStyle = .dark
            default:
                itemStackView.overrideUserInterfaceStyle = .light
            }
        }
    }

    private func updateVisibility() {
        guard let window = windowScene.keyWindow,
              let statusBarManager = windowScene.statusBarManager
        else { return }

        if shouldShowItems {
            if itemStackView.superview == nil {
                window.addSubview(itemStackView)

                NSLayoutConstraint.activate([
                    itemStackView.rightAnchor.constraint(equalTo: window.rightAnchor, constant: -10),
                    itemStackView.topAnchor.constraint(equalTo: window.topAnchor),
                    itemStackView.heightAnchor.constraint(equalToConstant: statusBarManager.statusBarFrame.height - 1) // Tweaking base line
                ])

                NotificationCenter.default.post(name: .StatusBarManagerDidUpdateVisibility, object: self)
            }
        } else {
            if itemStackView.superview != nil {
                itemStackView.removeFromSuperview()
                NotificationCenter.default.post(name: .StatusBarManagerDidUpdateVisibility, object: self)
            }
        }
    }

    var isStatusBarVisible: Bool {
        return shouldShowItems
    }

    private var shouldShowItems: Bool {
        guard let statusBarManager = windowScene.statusBarManager else {
            return false
        }

        return !statusBarManager.isStatusBarHidden && isRightEdgeSpaceAvailable
    }

    private var isRightEdgeSpaceAvailable: Bool {
        // This is based on the assumption that the app should be placed left side in split view
        return windowScene.multitaskState?.isSplitted ?? false
    }
}

struct StatusBarItem {
    var text: String
    var symbolName: String?
}

fileprivate class StatusBarItemView: UIStackView {
    static let symbolConfiguration = UIImage.SymbolConfiguration(
        pointSize: 10,
        weight: .regular,
        scale: .default
    )

    let item: StatusBarItem

    lazy var label = {
        let label = UILabel()
        label.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        return label
    }()

    lazy var symbolImageView = {
        let imageView = UIImageView()
        imageView.preferredSymbolConfiguration = Self.symbolConfiguration
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    init(item: StatusBarItem) {
        self.item = item

        // https://stackoverflow.com/q/36502790
        super.init(frame: .zero)

        axis = .horizontal
        alignment = .center
        distribution = .equalSpacing
        spacing = 2

        if let symbolName = item.symbolName {
            symbolImageView.image = UIImage(systemName: symbolName, withConfiguration: Self.symbolConfiguration)
            symbolImageView.tintColor = .label
            addArrangedSubview(symbolImageView)
        }

        label.text = item.text
        addArrangedSubview(label)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
