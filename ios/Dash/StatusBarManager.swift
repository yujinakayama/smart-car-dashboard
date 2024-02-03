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

typealias StatusBarSlot = CaseIterable & Hashable

class StatusBarManager<Slot: StatusBarSlot> {
    let windowScene: UIWindowScene

    private let itemViews: [Slot: StatusBarItemView]

    private let stackView = {
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

        itemViews = Slot.allCases.reduce(into: [Slot: StatusBarItemView](), { (dictionary, slot) in
            let view = StatusBarItemView()
            dictionary[slot] = view
        })

        for slot in Slot.allCases {
            let view = itemViews[slot]!
            stackView.addArrangedSubview(view)
        }

        updateAppearance()

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

    func setItem(_ item: StatusBarItem, for slot: Slot) {
        itemViews[slot]!.item = item
    }

    func removeItem(for slot: Slot) {
        itemViews[slot]!.item = nil
    }

    func updateAppearance() {
        updateStyle()
        updateVisibility()
    }

    private func updateStyle() {
        guard let statusBarManager = windowScene.statusBarManager else { return }

        switch statusBarManager.statusBarStyle {
        case .lightContent:
            stackView.overrideUserInterfaceStyle = .dark
        case .darkContent:
            stackView.overrideUserInterfaceStyle = .light
        default:
            switch windowScene.traitCollection.userInterfaceStyle {
            case .dark:
                stackView.overrideUserInterfaceStyle = .dark
            default:
                stackView.overrideUserInterfaceStyle = .light
            }
        }
    }

    private func updateVisibility() {
        guard let window = windowScene.keyWindow,
              let statusBarManager = windowScene.statusBarManager
        else { return }

        if canShowItems {
            if stackView.superview == nil {
                window.addSubview(stackView)

                NSLayoutConstraint.activate([
                    stackView.rightAnchor.constraint(equalTo: window.rightAnchor, constant: -10),
                    stackView.topAnchor.constraint(equalTo: window.topAnchor),
                    stackView.heightAnchor.constraint(equalToConstant: statusBarManager.statusBarFrame.height - 1) // Tweaking base line
                ])

                NotificationCenter.default.post(name: .StatusBarManagerDidUpdateVisibility, object: self)
            }
        } else {
            if stackView.superview != nil {
                stackView.removeFromSuperview()
                NotificationCenter.default.post(name: .StatusBarManagerDidUpdateVisibility, object: self)
            }
        }
    }

    var canShowItems: Bool {
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
    var unit: String?
    var symbolName: String?
}

fileprivate let symbolConfiguration = UIImage.SymbolConfiguration(
    pointSize: 10,
    weight: .regular,
    scale: .default
)

fileprivate class StatusBarItemView: UIStackView {
    var item: StatusBarItem? {
        didSet {
            applyItem()
        }
    }

    private let label = {
        let label = UILabel()
        label.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        return label
    }()

    private let symbolImageView = {
        let imageView = UIImageView()
        imageView.tintColor = .label
        imageView.preferredSymbolConfiguration = symbolConfiguration
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    init() {
        // https://stackoverflow.com/q/36502790
        super.init(frame: .zero)

        axis = .horizontal
        alignment = .center
        distribution = .equalSpacing
        spacing = 2

        addArrangedSubview(symbolImageView)
        addArrangedSubview(label)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func applyItem() {
        if let symbolName = item?.symbolName {
            symbolImageView.image = UIImage(systemName: symbolName, withConfiguration: symbolConfiguration)
        } else {
            symbolImageView.image = nil
        }

        if let text = item?.text {
            var attributedString = AttributedString(text, attributes: .init([
                .font: UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
            ]))

            if let unit = item?.unit {
                attributedString.append(AttributedString(unit, attributes: .init([
                    .font: UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium)
                ])))
            }

            label.attributedText = NSAttributedString(attributedString)
        } else {
            label.text = nil
        }

        isHidden = item == nil
    }
}
