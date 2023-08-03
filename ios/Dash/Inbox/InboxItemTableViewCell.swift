//
//  InboxItemTableViewCell.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/02/04.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit

class InboxItemTableViewCell: UITableViewCell {
    typealias Icon = (image: UIImage, color: UIColor)

    static let screenScale = UIScreen.main.scale
    static let minimumWebsiteIconSizeToDisplay = CGSize(width: 33, height: 33) // Reject 32px

    @IBOutlet weak var iconBackgroundView: BorderedView!
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var detailLabel: UILabel!
    @IBOutlet weak var actionStackView: UIStackView!

    let openStatusView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBlue
        return view
    }()

    @IBOutlet weak var iconImageViewSmallWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var iconImageViewSmallHeightConstraint: NSLayoutConstraint!

    @IBOutlet var iconImageViewNoMarginConstraints: [NSLayoutConstraint]!

    let parkingSearchButton: UIButton = {
        let fontMetrics = UIFontMetrics(forTextStyle: .subheadline)
        let font = fontMetrics.scaledFont(for: .boldSystemFont(ofSize: 15))

        var configuration = UIButton.Configuration.gray()
        configuration.buttonSize = .small
        configuration.cornerStyle = .capsule
        configuration.attributedTitle = AttributedString(String(localized: "Search Parkings"), attributes: .init([.font: font]))

        let button = UIButton(configuration: configuration)
        button.setContentHuggingPriority(.required, for: .horizontal)
        return button
    }()

    var defaultIconCornerRadius: CGFloat!
    
    var task: Task<Void, Error>?
    let imageLoader = ImageLoader()

    override func awakeFromNib() {
        defaultIconCornerRadius = iconBackgroundView.cornerRadius

        addOpenStatusView()

        actionStackView.addArrangedSubview(parkingSearchButton)

        // Not sure why but constraints are reset to Storyboard's state when app goes background and back to foreground
        // https://stackoverflow.com/questions/58376388/constraints-resets-when-app-is-going-in-background-ios-13
        NotificationCenter.default.addObserver(forName: UIScene.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] (notification) in
            self?.setNeedsUpdateConstraints()
        }
    }

    private func addOpenStatusView() {
        // We add openStatusView to UITableViewCell itself rather than its contentView
        // so that openStatusView won't be indented in editing mode.
        addSubview(openStatusView)

        openStatusView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            openStatusView.leadingAnchor.constraint(equalTo: leadingAnchor),
            openStatusView.widthAnchor.constraint(equalToConstant: 4),
            openStatusView.topAnchor.constraint(equalTo: topAnchor),
            bottomAnchor.constraint(equalTo: openStatusView.bottomAnchor)
        ])
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        task?.cancel()
        task = nil
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        // The unintentional constraints reset also happens when changing to dark mode
        setNeedsUpdateConstraints()

        updateActionButtonVisibility()
    }

    // https://rolandleth.com/tech/blog/increasing-the-tap-area-of-a-uibutton
    // https://khanlou.com/2018/09/hacking-hit-tests/
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let defaultHitView = super.hitTest(point, with: event)

        guard defaultHitView == contentView, !actionStackView.isHidden else {
            return defaultHitView
        }

        for actionButton in actionStackView.arrangedSubviews {
            if actionButton.isHidden { continue }

            // If the tapped point is within horizontal range of an action button (even if vertially outside),
            // the tap should be targetted to the button (i.e. enlarging vertial tappable area).
            let pointInActionButtonSpace = actionButton.convert(point, from: self)
            let actionButtonHorizontalRange = actionButton.bounds.minX...actionButton.bounds.maxX
            if actionButtonHorizontalRange.contains(pointInActionButtonSpace.x) {
                return actionButton
            }
        }

        return defaultHitView
    }
    
    var item: InboxItemProtocol? {
        didSet {
            iconShape = .standardRoundedRectangle

            switch item {
            case let location as InboxLocation:
                configureView(for: location)
            case let musicItem as MusicItem:
                configureView(for: musicItem)
            case let video as Video:
                configureView(for: video)
            case let website as Website:
                configureView(for: website)
            default:
                configureView(for: item)
            }

            updateActionButtonVisibility()

            openStatusView.isHidden = item?.hasBeenOpened ?? true
        }
    }

    private func configureView(for location: InboxLocation) {
        let icon = PointOfInterestIcon(categories: location.categories)

        iconType = .template
        iconImageView.image = icon.image
        iconBackgroundView.backgroundColor = icon.color

        nameLabel.text = location.name
        detailLabel.text = location.formattedAddress ?? location.address.country
    }

    private func configureView(for musicItem: MusicItem) {
        iconType = .template
        iconImageView.image = UIImage(systemName: "music.note")
        iconBackgroundView.backgroundColor = .systemPink

        nameLabel.text = musicItem.name
        detailLabel.text = musicItem.creator

        if let artworkURL = musicItem.artworkURL(size: iconImagePixelSize) {
            task = Task {
                try await setIconImage(from: artworkURL, shape: .sharpRoundedRectangle)
            }
        }
    }

    private func configureView(for video: Video) {
        iconType = .template
        iconImageView.image = UIImage(systemName: "film")
        iconBackgroundView.backgroundColor = .systemTeal

        nameLabel.text = video.title
        detailLabel.text = video.creator

        if let thumbnailURL = video.thumbnailURL {
            task = Task {
                try await setIconImage(from: thumbnailURL, shape: .circle)
            }
        }
    }

    private func configureView(for website: Website) {
        iconType = .template
        iconImageView.image = UIImage(systemName: "safari.fill")
        iconBackgroundView.backgroundColor = .systemBlue

        nameLabel.text = website.title ?? website.url.absoluteString
        detailLabel.text = website.simplifiedHost

        task = Task {
            guard let image = await website.icon(minimumSize: Self.minimumWebsiteIconSizeToDisplay).image else { return }

            try Task.checkCancellation()

            iconImageView.image = image
            iconBackgroundView.backgroundColor = .white
            iconType = .image
            iconShape = .standardRoundedRectangle
        }
    }

    private func configureView(for unknownItem: InboxItemProtocol?) {
        iconType = .template
        iconImageView.image = UIImage(systemName: "questionmark")
        iconBackgroundView.backgroundColor = .gray

        nameLabel.text = String(localized: "Unknown Item")
        detailLabel.text = unknownItem?.url.absoluteString
    }
    
    private func setIconImage(from url: URL, shape: IconShape) async throws {
        if let image = try? await imageLoader.loadImage(from: url) {
            try Task.checkCancellation()

            iconImageView.image = image
            iconBackgroundView.backgroundColor = .white
            iconType = .image
            iconShape = shape
        }
    }

    private func updateActionButtonVisibility() {
        let visible = item is InboxLocation && traitCollection.horizontalSizeClass != .compact
        parkingSearchButton.isHidden = !visible

        actionStackView.isHidden = actionStackView.arrangedSubviews.allSatisfy { $0.isHidden }
    }

    enum IconType {
        case template
        case image
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

    enum IconShape {
        case standardRoundedRectangle
        case sharpRoundedRectangle
        case circle
    }

    private var iconShape: IconShape = .standardRoundedRectangle {
        didSet {
            switch iconShape {
            case .standardRoundedRectangle:
                iconBackgroundView.cornerRadius = defaultIconCornerRadius
            case .sharpRoundedRectangle:
                iconBackgroundView.cornerRadius = 2
            case .circle:
                iconBackgroundView.cornerRadius = iconBackgroundView.bounds.width / 2
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
            width: pointSize.width * InboxItemTableViewCell.screenScale,
            height: pointSize.height * InboxItemTableViewCell.screenScale
        )
    }
}
