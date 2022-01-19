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
            button.setNeedsUpdateConfiguration()
        }
    }

    public var parkingInformation: OfficialParkingSearch.ParkingInformation?

    let fontMetrics = UIFontMetrics(forTextStyle: .callout)

    public lazy var button: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.imagePadding = 4
        configuration.imagePlacement = .trailing
        configuration.imageColorTransformer = UIConfigurationColorTransformer({ [unowned self] (originalColor) in
            return self.tintColor ?? originalColor
        })

        let button = UIButton(configuration: configuration)
        button.configurationUpdateHandler = { [weak self] (button) in self?.updateButton() }
        return button
    }()


    lazy var regularFontAttributes = AttributeContainer([
        .font: fontMetrics.scaledFont(for: UIFont.systemFont(ofSize: Self.baseFontSize))
    ])

    lazy var semiboldFontAttributes = AttributeContainer([
        .font: fontMetrics.scaledFont(for: UIFont.systemFont(ofSize: Self.baseFontSize, weight: .semibold))
    ])

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

        addArrangedSubview(button)

        if let insets = button.configuration?.contentInsets {
            let maxButtonHeight = infoImage.size.height + insets.top + insets.bottom
            button.heightAnchor.constraint(equalToConstant: maxButtonHeight).isActive = true
        }
    }

    func updateButton() {
        guard var configuration = button.configuration else { return }

        switch state {
        case .idle:
            button.isEnabled = false
            configuration.title = nil
            configuration.image = nil
            configuration.showsActivityIndicator = false
        case .searching:
            button.isEnabled = false
            configuration.attributedTitle = AttributedString("公式駐車場を検索中", attributes: regularFontAttributes)
            configuration.baseForegroundColor = .secondaryLabel
            configuration.image = nil
            configuration.showsActivityIndicator = true
        case .actionRequired:
            button.isEnabled = true
            configuration.attributedTitle = AttributedString("公式駐車場検索エラー・要操作", attributes: semiboldFontAttributes)
            configuration.baseForegroundColor = .label
            configuration.image = exclamationImage
            configuration.showsActivityIndicator = false
        case .found:
            button.isEnabled = true

            var description: String?

            if let parkingInformation = parkingInformation {
                if let capacity = parkingInformation.capacity {
                    description = "\(capacity)台"
                } else if let existence = parkingInformation.existence {
                    description = existence ? "あり" : "なし"
                }
            }

            if let description = description {
                configuration.attributedTitle = AttributedString("公式駐車場: \(description)", attributes: semiboldFontAttributes)
            } else {
                configuration.attributedTitle = AttributedString("公式駐車場", attributes: semiboldFontAttributes)
            }

            configuration.baseForegroundColor = .label
            configuration.image = infoImage
            configuration.showsActivityIndicator = false
        case .notFound:
            button.isEnabled = true
            configuration.attributedTitle = AttributedString("公式駐車場不明", attributes: regularFontAttributes)
            configuration.baseForegroundColor = .secondaryLabel
            configuration.image = infoImage
            configuration.showsActivityIndicator = false
        }

        button.configuration = configuration
    }
}
