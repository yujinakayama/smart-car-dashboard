//
//  PointOfInterestViewController.swift
//  Dash
//
//  Created by Yuji Nakayama on 2023/07/23.
//  Copyright © 2023 Yuji Nakayama. All rights reserved.
//

import UIKit

protocol PointOfInterestViewControllerDelegate: NSObject {
    func pointOfInterestViewController(_ viewController: PointOfInterestViewController, didFetchFullLocation fullLocation: FullLocation, fromPartialLocation partialLocation: PartialLocation)
}

class PointOfInterestViewController: UIViewController {
    weak var delegate: PointOfInterestViewControllerDelegate?
    let searchParkingsHandler: (Location) -> Void
    
    init(delegate: PointOfInterestViewControllerDelegate? = nil, searchParkingsHandler: @escaping (Location) -> Void) {
        self.delegate = delegate
        self.searchParkingsHandler = searchParkingsHandler
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var annotation: PointOfInterestAnnotation? {
        didSet {
            if let location = annotation?.location {
                update(for: location)
                if case .partial(let partialLocation) = location {
                    fetchFullLocation(partialLocation: partialLocation)
                }
            } else {
                partialLocationTask?.cancel()
            }
        }
    }

    var location: Location? {
        annotation?.location
    }

    private var partialLocationTask: Task<Void, Never>?

    private lazy var contentView: UIView = {
        let stackView = UIStackView(arrangedSubviews: [
            titleLabel,
            descriptionLabel,
            actionStackView,
        ])

        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.distribution = .fill

        stackView.spacing = 4
        stackView.setCustomSpacing(12, after: descriptionLabel)

        return stackView
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .label
        label.numberOfLines = 2

        let fontMetrics = UIFontMetrics(forTextStyle: .title1)
        let font = fontMetrics.scaledFont(for: .boldSystemFont(ofSize: 28))
        label.font = font
        label.adjustsFontForContentSizeCategory = true

        return label
    }()

    private lazy var descriptionLabel: UILabel = {
        let label = UILabel()
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.adjustsFontForContentSizeCategory = true
        return label
    }()


    private lazy var actionStackView: UIView = {
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

    private lazy var directionsButton: UIButton = {
        let button = makeButton(
            systemImageName: "arrow.triangle.turn.up.right.circle.fill",
            subtitle: String(localized: "Directions"),
            foregroundColor: .white,
            backgroundColor: .link // Not sure why but setting view.tintColor makes button's target-action not firing
        )

        button.addAction(.init(handler: { [weak self] _ in
            guard let location = self?.location else { return }
            LocationActions.OpenDirectionsInAppleMaps(location: location).perform()
        }), for: .touchUpInside)
        
        return button
    }()

    private lazy var parkingSearchButton: UIButton = {
        let button = makeButton(
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

        button.addAction(.init(handler: { [weak self] _ in
            guard let self = self, let location = self.location else { return }
            self.searchParkingsHandler(location)
        }), for: .touchUpInside)
        
        return button
    }()

    private lazy var moreActionsButton: UIButton = {
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
    
    private func update(for location: Location) {
        partialLocationTask?.cancel()

        titleLabel.text = location.name

        descriptionLabel.text = location.description

        switch location {
        case .full(let fullLocation):
            moreActionsButton.menu = LocationActions.makeMenu(for: [
                LocationActions.SearchWeb(fullLocation: fullLocation, viewController: self),
                LocationActions.OpenWebsite(fullLocation: fullLocation, viewController: self),
                LocationActions.OpenInTabelog(fullLocation: fullLocation, viewController: self),
                LocationActions.AddToInbox(fullLocation: fullLocation),
                LocationActions.OpenDirectionsInGoogleMaps(location: location),
                LocationActions.OpenDirectionsInYahooCarNavi(location: location),
            ].filter { $0.isPerformable })
        default:
            moreActionsButton.menu = LocationActions.makeMenu(for: [
                LocationActions.OpenDirectionsInGoogleMaps(location: location),
                LocationActions.OpenDirectionsInYahooCarNavi(location: location),
            ].filter { $0.isPerformable })
        }
    }
    
    private func fetchFullLocation(partialLocation: PartialLocation) {
        partialLocationTask = Task {
            do {
                let fullLocation = try await partialLocation.fullLocation

                try Task.checkCancellation()

                UIView.transition(with: view, duration: 0.25, options: .transitionCrossDissolve) {
                    self.update(for: .full(fullLocation))
                }

                delegate?.pointOfInterestViewController(self, didFetchFullLocation: fullLocation, fromPartialLocation: partialLocation)
            } catch {
                logger.error(error)
            }
        }
    }
}

fileprivate func makeButton(systemImageName: String, subtitle: String, foregroundColor: UIColor, backgroundColor: UIColor) -> UIButton {
    var configuration = UIButton.Configuration.filled()

    configuration.baseForegroundColor = foregroundColor
    configuration.baseBackgroundColor = backgroundColor
    configuration.contentInsets = .init(top: 10, leading: 8, bottom: 8, trailing: 8)
    configuration.cornerStyle = .medium

    let symbolConfiguration = UIImage.SymbolConfiguration(textStyle: .headline)
    configuration.image = UIImage(systemName: systemImageName, withConfiguration: symbolConfiguration)
    configuration.imagePlacement = .top
    configuration.imagePadding = 8

    let fontMetrics = UIFontMetrics(forTextStyle: .subheadline)
    let font = fontMetrics.scaledFont(for: .boldSystemFont(ofSize: 12))
    configuration.attributedSubtitle = AttributedString(subtitle, attributes: .init([.font: font]))

    return UIButton(configuration: configuration)
}
