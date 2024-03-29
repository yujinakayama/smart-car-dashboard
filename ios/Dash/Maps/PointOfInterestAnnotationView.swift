//
//  PointOfInterestAnnotationView.swift
//  Dash
//
//  Created by Yuji Nakayama on 2021/07/22.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import MapKit

class PointOfInterestAnnotationView: MKMarkerAnnotationView {
    override var annotation: MKAnnotation? {
        didSet {
            updateGlyph()
        }
    }

    lazy var callout = Callout(annotationView: self)

    init(annotation: PointOfInterestAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)

        collisionMode = .none
        displayPriority = .required

        updateGlyph()

        _ = callout
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        callout.annotationViewDidLayoutSubviews()
    }

    func updateGlyph() {
        guard let annotation = annotation as? PointOfInterestAnnotation else { return }
        let icon = PointOfInterestIcon(categories: annotation.categories)
        glyphImage = icon.image
        markerTintColor = icon.color
    }
}

extension PointOfInterestAnnotationView {
    class Callout {
        static let departureColor = UIColor(displayP3Red: 76 / 256, green: 217 / 256, blue: 100 / 256, alpha: 1)

        weak var annotationView: PointOfInterestAnnotationView?

        init(annotationView: PointOfInterestAnnotationView) {
            self.annotationView = annotationView

            annotationView.canShowCallout = true
            annotationView.detailCalloutAccessoryView = view
        }

        lazy var view: UIView = {
            // Not sure why but setting a naked stack view as an accessory view causes strange layout
            let view = WrapperView(contentView: stackView)
            view.layoutMargins = .zero
            return view
        }()

        lazy var stackView: UIView = {
            let stackView = UIStackView(arrangedSubviews: [
                departureButton,
                parkingSearchButton,
            ])

            stackView.axis = .vertical
            stackView.alignment = .fill
            stackView.distribution = .fillEqually
            stackView.spacing = 10

            return stackView
        }()

        lazy var departureButton: UIButton = makeButton(title: String(localized: "Get Directions"), backgroundColor: Self.departureColor)
        lazy var parkingSearchButton: UIButton = makeButton(title: String(localized: "Search Parkings"), backgroundColor: .systemBlue)

        func makeButton(title: String, backgroundColor: UIColor) -> UIButton {
            var configuration = UIButton.Configuration.filled()
            configuration.title = title
            configuration.baseBackgroundColor = backgroundColor
            configuration.buttonSize = .medium

            return UIButton(configuration: configuration)
        }

        var privateTitleLabel: UILabel? {
            return privateCalloutView?.value(forKey: "_titleLabel") as? UILabel
        }

        var privateCalloutView: UIView? {
            var currentView: UIView? = view.superview

            for _ in 0..<10 {
                guard let view = currentView else { return nil }

                if String(describing: type(of: view)) == "MKSmallCalloutView" {
                    return view
                }

                currentView = view.superview
            }

            return nil
        }

        var hasForcedLayout = false

        func annotationViewDidLayoutSubviews() {
            if !hasForcedLayout, privateTitleLabel != nil {
                forceLayout()
                hasForcedLayout = true
            }
        }

        func forceLayout() {
            guard let annotationView = annotationView else { return }
            annotationView.detailCalloutAccessoryView = nil
            annotationView.detailCalloutAccessoryView = view
        }
    }
}


fileprivate class WrapperView: UIView {
    let contentView: UIView

    init(contentView: UIView) {
        self.contentView = contentView

        super.init(frame: .zero)

        addSubview(contentView)

        contentView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            layoutMarginsGuide.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
            layoutMarginsGuide.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        let size = contentView.intrinsicContentSize

        return .init(
            width: size.width + layoutMargins.left + layoutMargins.right,
            height: size.height + layoutMargins.top + layoutMargins.bottom
        )
    }
}
