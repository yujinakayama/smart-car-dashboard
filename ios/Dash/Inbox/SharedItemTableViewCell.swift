//
//  SharedItemTableViewCell.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/02/04.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit
import PINRemoteImage

class SharedItemTableViewCell: UITableViewCell {
    enum IconType {
        case template
        case image
    }

    static let screenScale = UIScreen.main.scale

    @IBOutlet weak var iconBackgroundView: BorderedView!
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var detailLabel: UILabel!
    @IBOutlet weak var actionStackView: UIStackView!
    @IBOutlet weak var openedStatusView: UIView!

    @IBOutlet weak var iconImageViewSmallWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var iconImageViewSmallHeightConstraint: NSLayoutConstraint!

    @IBOutlet var iconImageViewNoMarginConstraints: [NSLayoutConstraint]!

    let parkingSearchButton: UIButton = {
        let fontMetrics = UIFontMetrics(forTextStyle: .subheadline)
        let font = fontMetrics.scaledFont(for: .boldSystemFont(ofSize: 15))

        var configuration = UIButton.Configuration.gray()
        configuration.buttonSize = .small
        configuration.cornerStyle = .capsule
        configuration.attributedTitle = AttributedString("駐車場検索", attributes: .init([.font: font]))

        let button = UIButton(configuration: configuration)
        button.setContentHuggingPriority(.required, for: .horizontal)
        return button
    }()

    var defaultIconCornerRadius: CGFloat!

    override func awakeFromNib() {
        defaultIconCornerRadius = iconBackgroundView.cornerRadius

        actionStackView.addArrangedSubview(parkingSearchButton)

        // Not sure why but constraints are reset to Storyboard's state when app goes background and back to foreground
        // https://stackoverflow.com/questions/58376388/constraints-resets-when-app-is-going-in-background-ios-13
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] (notification) in
            self?.setNeedsUpdateConstraints()
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        iconImageView.pin_cancelImageDownload()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // The unintentional constraints reset also happens when changing to dark mode
        setNeedsUpdateConstraints()
    }

    var item: SharedItemProtocol? {
        didSet {
            iconBackgroundView.cornerRadius = defaultIconCornerRadius

            switch item {
            case let location as Location:
                configureView(for: location)
            case let musicItem as MusicItem:
                configureView(for: musicItem)
            case let website as Website:
                configureView(for: website)
            default:
                configureView(for: item)
            }

            actionStackView.isHidden = actionStackView.arrangedSubviews.allSatisfy { $0.isHidden }
            openedStatusView.isHidden = item?.hasBeenOpened ?? true
        }
    }

    private func configureView(for location: Location) {
        iconType = .template
        iconImageView.image = UIImage(systemName: "mappin")
        iconBackgroundView.backgroundColor = UIColor(named: "Location Icon Color")

        nameLabel.text = location.name
        detailLabel.text = location.formattedAddress ?? location.address.country

        parkingSearchButton.isHidden = false
    }

    private func configureView(for musicItem: MusicItem) {
        iconType = .template
        iconImageView.image = UIImage(systemName: "music.note")
        iconBackgroundView.backgroundColor = .systemPink

        if let artworkURL = musicItem.artworkURL(size: iconImagePixelSize) {
            setRemoteImage(url: artworkURL) { (error) in
                if error == nil {
                    self.iconBackgroundView.cornerRadius = 2
                }
            }
        }

        nameLabel.text = musicItem.name
        detailLabel.text = musicItem.creator

        parkingSearchButton.isHidden = true
    }

    private func configureView(for website: Website) {
        iconType = .template
        iconImageView.image = UIImage(systemName: "safari.fill")
        iconBackgroundView.backgroundColor = .systemBlue

        website.icon.getURL { (iconURL) in
            if let iconURL = iconURL {
                DispatchQueue.main.async {
                    self.setRemoteImage(url: iconURL)
                }
            }
        }

        nameLabel.text = website.title ?? website.url.absoluteString
        detailLabel.text = website.url.host

        parkingSearchButton.isHidden = true
    }

    private func configureView(for unknownItem: SharedItemProtocol?) {
        iconType = .template
        iconImageView.image = UIImage(systemName: "questionmark")
        iconBackgroundView.backgroundColor = .gray

        nameLabel.text = "不明なアイテム"
        detailLabel.text = unknownItem?.url.absoluteString

        parkingSearchButton.isHidden = true
    }

    private func setRemoteImage(url: URL, completionHandler: ((Error?) -> Void)? = nil) {
        let originalIconType = iconType
        let originalImage = iconImageView.image
        let originalBackgroundColor = iconBackgroundView.backgroundColor

        DispatchQueue.main.async {
            self.iconImageView.pin_setImage(from: url) { (result) in
                if result.error == nil {
                    self.iconType = .image
                    self.iconBackgroundView.backgroundColor = .white
                } else {
                    self.iconType = originalIconType
                    self.iconImageView.image = originalImage
                    self.iconBackgroundView.backgroundColor = originalBackgroundColor
                }

                completionHandler?(result.error)
            }
        }
    }

    private var iconType: IconType = .template {
        didSet {
            switch iconType {
            case .template:
                iconImageView.contentMode = .scaleAspectFit
            case .image:
                iconImageView.contentMode = .scaleAspectFill
            }

            if iconType != oldValue {
                setNeedsUpdateConstraints()
            }
        }
    }

    override func updateConstraints() {
        switch iconType {
        case .template:
            NSLayoutConstraint.deactivate(iconImageViewNoMarginConstraints)
            iconImageViewSmallWidthConstraint.isActive = true
            iconImageViewSmallHeightConstraint.isActive = true
        case .image:
            iconImageViewSmallWidthConstraint.isActive = false
            iconImageViewSmallHeightConstraint.isActive = false
            NSLayoutConstraint.activate(iconImageViewNoMarginConstraints)
        }

        super.updateConstraints()
    }

    var iconImagePixelSize: CGSize {
        let pointSize = iconBackgroundView.bounds.size

        return CGSize(
            width: pointSize.width * SharedItemTableViewCell.screenScale,
            height: pointSize.height * SharedItemTableViewCell.screenScale
        )
    }
}
