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
                actions = nil
            }
        }
    }

    private var actions: LocationActions?
    
    private var partialLocationTask: Task<Void, Never>?

    private lazy var contentView: UIView = {
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
            systemImageName: "car.fill",
            subtitle: String(localized: "Directions"),
            foregroundColor: .white,
            backgroundColor: .link // Not sure why but setting view.tintColor makes button's target-action not firing
        )

        button.addAction(.init(handler: { [weak self] _ in
            self?.actions?.action(for: .openDirectionsInAppleMaps)?.perform()
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
            self?.actions?.action(for: .searchParkings)?.perform()
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

        let actions = LocationActions(location: location, viewController: self, searchParkingsHandler: searchParkingsHandler)
        moreActionsButton.menu = actions.makeMenu(for: [
            .searchWeb,
            .openWebsite,
            .openDirectionsInGoogleMaps,
            .openDirectionsInYahooCarNavi
        ])

        self.actions = actions
    }
    
    private func fetchFullLocation(partialLocation: PartialLocation) {
        partialLocationTask = Task {
            do {
                let fullLocation = try await partialLocation.fullLocation
                try Task.checkCancellation()
                update(for: .full(fullLocation))
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
