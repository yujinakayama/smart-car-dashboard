//
//  OfficialParkingSearchStatusView.swift
//  ParkingSearchKit
//
//  Created by Yuji Nakayama on 2021/07/06.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import UIKit

public class OfficialParkingSearchStatusView: UIStackView {
    static let spacingBetweenTitleAndImage: CGFloat = 4
    static let baseFontSize: CGFloat = 16

    public var state: OfficialParkingSearch.State = .idle {
        didSet {
            applyState()
        }
    }

    let fontMetrics = UIFontMetrics(forTextStyle: .callout)

    public let button: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.imageView?.contentMode = .scaleAspectFit
        button.semanticContentAttribute = .forceRightToLeft
        return button
    }()

    public let activityIndicatorView = UIActivityIndicatorView()

    lazy var infoImage = UIImage(systemName: "info.circle", withConfiguration: symbolConfiguration)!
    lazy var exclamationImage = UIImage(systemName: "exclamationmark.circle", withConfiguration: symbolConfiguration)!

    let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: 20)

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    func commonInit() {
        axis = .horizontal
        alignment = .center
        distribution = .equalSpacing
        spacing = Self.spacingBetweenTitleAndImage

        layoutMargins = .init(top: 4, left: 11, bottom: 4, right: 8)
        isLayoutMarginsRelativeArrangement = true

        addArrangedSubview(button)
        addArrangedSubview(activityIndicatorView)

        button.heightAnchor.constraint(equalToConstant: infoImage.size.height + layoutMargins.top + layoutMargins.bottom).isActive = true
    }

    func applyState() {
        activityIndicatorView.stopAnimating()

        // We should first set button text nil and font, and then set actual text
        // to avoid flickering button text
        button.setTitle(nil, for: .normal)

        switch state {
        case .idle:
            button.isEnabled = false
        case .searching:
            button.isEnabled = false
            button.titleLabel?.font = fontMetrics.scaledFont(for: UIFont.systemFont(ofSize: Self.baseFontSize))
            button.setTitleColor(.secondaryLabel, for: .normal)
            button.setTitle("公式駐車場を検索中", for: .normal)
            button.setImage(nil, for: .normal)

            activityIndicatorView.startAnimating()
        case .actionRequired:
            button.isEnabled = true
            button.titleLabel?.font = fontMetrics.scaledFont(for: UIFont.systemFont(ofSize: Self.baseFontSize, weight: .semibold))
            button.setTitleColor(.label, for: .normal)
            button.setTitle("公式駐車場検索エラー・要操作", for: .normal)
            button.setImage(exclamationImage, for: .normal)
        case .found:
            button.isEnabled = true
            button.titleLabel?.font = fontMetrics.scaledFont(for: UIFont.systemFont(ofSize: Self.baseFontSize, weight: .semibold))
            button.setTitleColor(.label, for: .normal)
            button.setTitle("公式駐車場", for: .normal)
            button.setImage(infoImage, for: .normal)
        case .notFound:
            button.isEnabled = true
            button.titleLabel?.font = fontMetrics.scaledFont(for: UIFont.systemFont(ofSize: Self.baseFontSize))
            button.setTitleColor(.secondaryLabel, for: .normal)
            button.setTitle("公式駐車場不明", for: .normal)
            button.setImage(infoImage, for: .normal)
        }

        if button.image(for: .normal) != nil {
            // https://noahgilmore.com/blog/uibutton-padding/
            button.contentEdgeInsets = .init(top: 0, left: 0, bottom: 0, right: Self.spacingBetweenTitleAndImage)
            button.imageEdgeInsets = .init(top: 0, left: Self.spacingBetweenTitleAndImage, bottom: 0, right: -Self.spacingBetweenTitleAndImage)
        } else {
            button.contentEdgeInsets = .zero
            button.imageEdgeInsets = .zero
        }
    }
}
