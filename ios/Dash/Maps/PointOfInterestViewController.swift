//
//  PointOfInterestViewController.swift
//  Dash
//
//  Created by Yuji Nakayama on 2023/07/23.
//  Copyright © 2023 Yuji Nakayama. All rights reserved.
//

import UIKit

class PointOfInterestViewController: UIViewController {
    var annotation: PointOfInterestAnnotation? {
        didSet {
            titleLabel.text = annotation?.title ?? nil
        }
    }

    lazy var contentView: UIView = {
        let stackView = UIStackView(arrangedSubviews: [
            titleLabel,
            actionStackView,
        ])

        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.distribution = .equalSpacing
        stackView.spacing = 12
        
        return stackView
    }()

    lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .label
        label.numberOfLines = 2

        let fontMetrics = UIFontMetrics(forTextStyle: .title1)
        let font = fontMetrics.scaledFont(for: .boldSystemFont(ofSize: 28))
        label.font = font
        label.adjustsFontForContentSizeCategory = true

        return label
    }()
    
    lazy var actionStackView: UIView = {
        let stackView = UIStackView(arrangedSubviews: [
            directionsButton,
            parkingSearchButton,
            moreActionsButton
        ])

        stackView.axis = .horizontal
        stackView.alignment = .fill
        stackView.distribution = .fillEqually
        stackView.spacing = 8

        return stackView
    }()

    lazy var directionsButton: UIButton = makeButton(
        systemImageName: "car.fill",
        subtitle: String(localized: "Get Directions"),
        foregroundColor: .white,
        backgroundColor: .link // Not sure why but setting view.tintColor makes button's target-action not firing
    )

    lazy var parkingSearchButton: UIButton = makeButton(
        systemImageName: "parkingsign",
        subtitle: String(localized: "Search Parkings"),
        foregroundColor: UIColor(dynamicProvider: { [unowned self] traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return .white
            } else {
                return .link
            }
        }),
        backgroundColor: .systemFill
    )

    lazy var moreActionsButton: UIButton = {
        let button = makeButton(
            systemImageName: "ellipsis",
            subtitle: String(localized: "More"),
            foregroundColor: UIColor(dynamicProvider: { [unowned self] traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    return .white
                } else {
                    return .link
                }
            }),
            backgroundColor: .systemFill
        )
        
        button.showsMenuAsPrimaryAction = true
        
        return button
    }()

    
    override func viewDidLoad() {
        super.viewDidLoad()

        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentView)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: contentView.topAnchor),
            view.bottomAnchor.constraint(greaterThanOrEqualTo: contentView.bottomAnchor),
            view.leftAnchor.constraint(equalTo: contentView.leftAnchor),
            view.rightAnchor.constraint(equalTo: contentView.rightAnchor),
        ])
    }
}

fileprivate func makeButton(systemImageName: String, subtitle: String, foregroundColor: UIColor, backgroundColor: UIColor) -> UIButton {
    var configuration = UIButton.Configuration.filled()

    configuration.baseForegroundColor = foregroundColor
    configuration.baseBackgroundColor = backgroundColor
    configuration.contentInsets = .init(top: 10, leading: 8, bottom: 8, trailing: 8)
    configuration.cornerStyle = .medium

    let symbolConfiguration = UIImage.SymbolConfiguration(textStyle: .callout)
    configuration.image = UIImage(systemName: systemImageName, withConfiguration: symbolConfiguration)
    configuration.imagePlacement = .top
    configuration.imagePadding = 8

    let fontMetrics = UIFontMetrics(forTextStyle: .subheadline)
    let font = fontMetrics.scaledFont(for: .boldSystemFont(ofSize: 12))
    configuration.attributedSubtitle = AttributedString(subtitle, attributes: .init([.font: font]))

    return UIButton(configuration: configuration)
}
