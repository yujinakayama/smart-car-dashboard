//
//  OfficialParkingSearchStatusView.swift
//  ParkingSearchKit
//
//  Created by Yuji Nakayama on 2021/07/06.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import UIKit

public class OfficialParkingSearchStatusView: UIStackView {
    public var state: OfficialParkingSearch.State = .idle {
        didSet {
            applyState()
        }
    }

    let fontMetrics = UIFontMetrics(forTextStyle: .caption1)

    public let label: UILabel = {
        let label = UILabel()
        label.adjustsFontForContentSizeCategory = true
        return label
    }()

    public let activityIndicatorView = UIActivityIndicatorView()

    public let informationButton: UIButton = {
        let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: 24)
        let image = UIImage(systemName: "info.circle", withConfiguration: symbolConfiguration)

        let button = UIButton()
        button.setImage(image, for: .normal)
        return button
    }()

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
        spacing = 6

        directionalLayoutMargins = .init(top: 6, leading: 10, bottom: 6, trailing: 10)
        isLayoutMarginsRelativeArrangement = true

        backgroundColor = .tertiarySystemFill
        layer.cornerRadius = 8

        addArrangedSubview(label)
        addArrangedSubview(activityIndicatorView)
        addArrangedSubview(informationButton)
    }

    func applyState() {
        label.isHidden = true
        activityIndicatorView.isHidden = true
        informationButton.isHidden = true

        switch state {
        case .idle:
            break
        case .searching:
            label.isHidden = false
            label.font = fontMetrics.scaledFont(for: UIFont.systemFont(ofSize: 13))
            label.textColor = .secondaryLabel
            label.text = "公式駐車場を検索中"

            activityIndicatorView.isHidden = false
            activityIndicatorView.startAnimating()
        case .actionRequired:
            label.isHidden = false
            label.font = fontMetrics.scaledFont(for: UIFont.systemFont(ofSize: 13, weight: .semibold))
            label.textColor = .label
            label.text = "要操作"

            informationButton.isHidden = false
        case .found:
            label.isHidden = false
            label.font = fontMetrics.scaledFont(for: UIFont.systemFont(ofSize: 13, weight: .semibold))
            label.textColor = .label
            label.text = "公式駐車場"

            informationButton.isHidden = false
        case .notFound:
            label.isHidden = false
            label.font = fontMetrics.scaledFont(for: UIFont.systemFont(ofSize: 13))
            label.textColor = .secondaryLabel
            label.text = "公式駐車場不明"

            informationButton.isHidden = false
        }
    }
}
