//
//  ParkingAnnotationView.swift
//  Dash
//
//  Created by Yuji Nakayama on 2021/05/05.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import MapKit

class ParkingAnnotationView: MKMarkerAnnotationView {
    override var annotation: MKAnnotation? {
        didSet {
            update()
        }
    }

    var parking: Parking? {
        return (annotation as? ParkingAnnotation)?.parking
    }

    lazy var callout = Callout(annotationView: self)

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)

        animatesWhenAdded = true
        collisionMode = .none
        displayPriority = .required

        update()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        callout.annotationViewDidLayoutSubviews()
    }

    func update() {
        guard let parking = parking else { return }

        if let rank = parking.rank {
            glyphText = "\(rank)位"

            markerTintColor = UIColor.link.blend(
                with: UIColor.systemGray,
                ratio: 1.0 - CGFloat(rank - 1) * 0.2
            )

            let zPriorityValue = MKAnnotationViewZPriority.defaultUnselected.rawValue - Float(rank - 1)
            zPriority = MKAnnotationViewZPriority(rawValue: zPriorityValue)
        } else {
            if parking.isClosed {
                glyphText = "×"
            } else {
                glyphText = "?"
            }

            markerTintColor = .systemGray
            zPriority = .min
        }

        callout.update()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        callout.annotationViewDidSetSelected(selected, animated: animated)
    }
}

extension ParkingAnnotationView {
    class Callout {
        static let departureColor = UIColor(displayP3Red: 76 / 256, green: 217 / 256, blue: 100 / 256, alpha: 1)

        weak var annotationView: ParkingAnnotationView?

        var parking: Parking? {
            return annotationView?.parking
        }

        init(annotationView: ParkingAnnotationView) {
            self.annotationView = annotationView

            hideDetails()

            annotationView.canShowCallout = true
            annotationView.leftCalloutAccessoryView = rankView
            annotationView.detailCalloutAccessoryView = contentView
            annotationView.rightCalloutAccessoryView = departureButton
        }

        lazy var rankView: RankView = {
            let rankView = RankView()
            rankView.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
            return rankView
        }()

        lazy var contentView: UIView = {
            let stackView = UIStackView(arrangedSubviews: [headerView, detailView])

            // Not arrannged
            tagListView.translatesAutoresizingMaskIntoConstraints = false
            stackView.addSubview(tagListView)
            stackView.trailingAnchor.constraint(equalTo: tagListView.trailingAnchor).isActive = true

            stackView.axis = .vertical
            stackView.alignment = .fill
            stackView.distribution = .equalSpacing
            stackView.spacing = 8
            return stackView
        }()

        lazy var tagListView = TagListView()
        let tagListViewConstraints = WeakReferenceArray<NSLayoutConstraint>()

        lazy var headerView: UIView = {
            let stackView = UIStackView(arrangedSubviews: [nameLabelControl, ellipsisButton, UIView()])
            stackView.axis = .horizontal
            stackView.alignment = .center
            stackView.distribution = .fill
            stackView.spacing = 6
            return stackView
        }()

        lazy var nameLabelControl = LabelControl(label: makeContentLabel(textColor: .secondaryLabel, multiline: false))

        lazy var ellipsisButton: UIButton = {
            let image = UIImage(systemName: "ellipsis.rectangle.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 20))

            let button = UIButton()
            button.setImage(image, for: .normal)
            button.tintColor = .tertiaryLabel
            button.addTarget(self, action: #selector(showDetails), for: .touchUpInside)
            button.setContentCompressionResistancePriority(.required, for: .horizontal)
            return button
        }()

        lazy var detailView: UIView = {
            let stackView = UIStackView(arrangedSubviews: [
                rulerView,
                capacityItemView,
                openingHoursItemView,
                priceDescriptionItemView,
                reservationView,
            ])

            stackView.axis = .vertical
            stackView.alignment = .fill
            stackView.distribution = .equalSpacing
            stackView.spacing = 8
            return stackView
        }()

        lazy var rulerView: UIView = {
            let view = UIView()
            view.backgroundColor = .tertiaryLabel
            view.heightAnchor.constraint(equalToConstant: 1.0 / UIScreen.main.scale).isActive = true
            return view
        }()

        lazy var capacityItemView = makeItemView(heading: "台数", contentLabel: capacityLabel)
        lazy var openingHoursItemView = makeItemView(heading: "営業時間", contentLabel: openingHoursLabel)
        lazy var priceDescriptionItemView = makeItemView(heading: "料金", contentLabel: priceDescriptionLabel)

        // Not sure why but adding a button without wrapper view to stack view breaks layout
        lazy var reservationView: UIView = {
            let view = UIView()

            view.addSubview(reservationButton)

            reservationButton.translatesAutoresizingMaskIntoConstraints = false

            NSLayoutConstraint.activate([
                reservationButton.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                view.bottomAnchor.constraint(equalTo: reservationButton.bottomAnchor),
                reservationButton.topAnchor.constraint(equalTo: view.topAnchor),
                view.trailingAnchor.constraint(equalTo: reservationButton.trailingAnchor),
                reservationButton.heightAnchor.constraint(equalToConstant: 28),
            ])

            return view
        }()

        lazy var reservationButton: UIButton = {
            let fontMetrics = UIFontMetrics(forTextStyle: .footnote)

            let button = UIButton()

            button.setBackgroundColor(.link, for: .normal)
            button.setTitleColor(.white, for: .normal)

            button.titleLabel?.adjustsFontForContentSizeCategory = true
            button.titleLabel?.adjustsFontSizeToFitWidth = true
            button.titleLabel?.font = fontMetrics.scaledFont(for: UIFont.systemFont(ofSize: 13, weight: .semibold))

            button.clipsToBounds = true
            button.layer.cornerRadius = 6

            return button
        }()

        lazy var capacityLabel = makeContentLabel()
        lazy var openingHoursLabel = makeContentLabel()
        lazy var priceDescriptionLabel = makeContentLabel()

        func makeItemView(heading: String, contentLabel: UILabel) -> UIView {
            let headingLabel = UILabel()
            headingLabel.adjustsFontForContentSizeCategory = true
            headingLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
            headingLabel.text = heading
            headingLabel.textColor = .secondaryLabel

            let stackView = UIStackView(arrangedSubviews: [headingLabel, contentLabel])
            stackView.axis = .vertical
            stackView.distribution = .fill
            return stackView
        }

        func makeContentLabel(textColor: UIColor = .label, multiline: Bool = true) -> UILabel {
            let label = UILabel()
            label.adjustsFontForContentSizeCategory = true
            label.font = UIFont.preferredFont(forTextStyle: .footnote)
            label.numberOfLines = multiline ? 0 : 1
            label.textColor = textColor
            return label
        }

        lazy var departureButton: UIButton = {
            let image = UIImage(systemName: "car.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 24))

            let button = UIButton()
            button.setImage(image, for: .normal)
            button.tintColor = .white
            button.setBackgroundColor(Self.departureColor, for: .normal)

            button.frame.size = CGSize(width: 40, height: 40)
            button.clipsToBounds = true
            button.layer.cornerRadius = 8

            button.addTarget(self, action: #selector(openDirectionsInMaps), for: .touchUpInside)

            return button
        }()

        func annotationViewDidLayoutSubviews() {
            if let titleLabel = privateTitleLabel, tagListViewConstraints.isEmpty {
                titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

                // We need to reconfigure constraints when titleLabel instance is recreated
                let constraints = [
                    tagListView.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 6),
                    tagListView.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor)
                ]

                NSLayoutConstraint.activate(constraints)
                tagListViewConstraints.append(contentsOf: constraints)

                forceLayout()
            }
        }

        var privateTitleLabel: UILabel? {
            return privateCalloutView?.value(forKey: "_titleLabel") as? UILabel
        }

        var privateCalloutView: UIView? {
            var currentView: UIView? = contentView.superview

            for _ in 0..<10 {
                guard let view = currentView else { return nil }

                if String(describing: type(of: view)) == "MKSmallCalloutView" {
                    return view
                }

                currentView = view.superview
            }

            return nil
        }

        func update() {
            guard let annotationView = annotationView, let parking = parking else { return }

            rankView.label.text = annotationView.glyphText
            rankView.tintColor = annotationView.markerTintColor

            tagListView.parking = parking

            nameLabelControl.label.text = normalizeText(parking.name)

            if tagListView.capacityTagView.isHidden, let description = normalizeText(parking.capacityDescription) {
                capacityLabel.text = description
                capacityItemView.isHidden = false
            } else {
                capacityLabel.text = nil
                capacityItemView.isHidden = true
            }

            if let description = normalizeText(parking.openingHoursDescription) {
                openingHoursLabel.text = description
                openingHoursItemView.isHidden = false
            } else {
                openingHoursLabel.text = nil
                openingHoursItemView.isHidden = true
            }

            if let description = normalizedPriceDescription {
                priceDescriptionLabel.text = description
                priceDescriptionItemView.isHidden = false
            } else {
                priceDescriptionLabel.text = nil
                priceDescriptionItemView.isHidden = true
            }

            if let provider = parking.reservationInfo?.provider, parking.reservationInfo?.url != nil {
                reservationButton.setTitle("\(provider)で予約する", for: .normal)
                reservationView.isHidden = false
            } else {
                reservationButton.setTitle(nil, for: .normal)
                reservationView.isHidden = true
            }
        }

        func normalizeText(_ text: String?) -> String? {
            guard let text = text else { return nil }

            let normalizedText = text.covertFullwidthAlphanumericsToHalfwidth().convertFullwidthWhitespacesToHalfwidth()

            let lines = normalizedText.split(separator: "\n")
            let trimmedLines = lines.map { $0.trimmingCharacters(in: .whitespaces) }.compactMap { $0 }
            return trimmedLines.joined(separator: "\n")
        }

        var normalizedPriceDescription: String? {
            guard let parking = parking, let text = normalizeText(parking.priceDescription) else { return nil }

            let lines = text.split(separator: "\n")

            let linePrefixToRemove = "全日 "

            let normalizedLines: [String] = lines.map { (line) in
                if line.hasPrefix(linePrefixToRemove) {
                    return String(line.dropFirst(linePrefixToRemove.count))
                } else {
                    return String(line)
                }
            }

            return normalizedLines.joined(separator: "\n")
        }

        @objc func showDetails() {
            detailView.isHidden = false
            ellipsisButton.isHidden = true
            forceLayout()
        }

        func forceLayout() {
            guard let annotationView = annotationView else { return }
            annotationView.detailCalloutAccessoryView = nil
            annotationView.detailCalloutAccessoryView = contentView
        }

        func annotationViewDidSetSelected(_ selected: Bool, animated: Bool) {
            if !selected {
                hideDetails()
            }
        }

        func hideDetails() {
            detailView.isHidden = true
            ellipsisButton.isHidden = false
        }

        @objc func openDirectionsInMaps() {
            guard let parking = parking else { return }

            let placemark = MKPlacemark(coordinate: parking.coordinate)
            let mapItem = MKMapItem(placemark: placemark)
            mapItem.name = normalizeText(parking.name)

            mapItem.openInMaps(launchOptions: [
                MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
            ])
        }
    }
}

extension ParkingAnnotationView.Callout {
    // We use this label in the callout view to enable context menu interaction
    // because MKAnnotationView doesn't allow non-UIControl views in the callout to receive touch events.
    // See the reference for mapView(_:annotationView:calloutAccessoryControlTapped:).
    class LabelControl: UIControl {
        let label: UILabel

        init(label: UILabel) {
            self.label = label
            super.init(frame: .zero)
            addSubview(label)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func layoutSubviews() {
            label.frame = bounds
        }

        override var intrinsicContentSize: CGSize {
            return label.intrinsicContentSize
        }

        // The followings are needed to avoid superfluous spacing above the label
        // when the detail view is expanded.

        override func alignmentRect(forFrame frame: CGRect) -> CGRect {
            return label.alignmentRect(forFrame: frame)
        }

        override func frame(forAlignmentRect alignmentRect: CGRect) -> CGRect {
            return label.frame(forAlignmentRect: alignmentRect)
        }

        override var alignmentRectInsets: UIEdgeInsets {
            return label.alignmentRectInsets
        }

        override var forFirstBaselineLayout: UIView {
            return label.forFirstBaselineLayout
        }

        override var forLastBaselineLayout: UIView {
            return label.forLastBaselineLayout
        }
    }
}

extension ParkingAnnotationView.Callout {
    class RankView: UIView {
        override var frame: CGRect {
            didSet {
                layer.cornerRadius = frame.width / 2
            }
        }

        lazy var label: UILabel = {
            let label = UILabel()
            label.adjustsFontSizeToFitWidth = true
            label.font = UIFont.systemFont(ofSize: 19, weight: .semibold)
            label.textAlignment = .center
            label.textColor = .white
            return label
        }()

        init() {
            super.init(frame: .zero)

            clipsToBounds = true

            label.translatesAutoresizingMaskIntoConstraints = false

            addSubview(label)

            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: centerXAnchor),
                label.centerYAnchor.constraint(equalTo: centerYAnchor),
                label.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.8),
            ])
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func tintColorDidChange() {
            super.tintColorDidChange()
            backgroundColor = tintColor
        }
    }
}

extension ParkingAnnotationView.Callout {
    class TagListView: UIStackView {
        let simpleCapacityRegularExpression = try! NSRegularExpression(pattern: "^\\d+台$")

        var parking: Parking? {
            didSet {
                update()
            }
        }

        init() {
            super.init(frame: .zero)

            axis = .horizontal
            spacing = 6

            addArrangedSubview(capacityTagView)
            addArrangedSubview(reservationTagView)
            addArrangedSubview(fullTagView)
            addArrangedSubview(crowdedTagView)
            addArrangedSubview(vacantTagView)
            addArrangedSubview(UIView())
        }

        required init(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update() {
            guard let parking = parking else { return }

            if hasSimpleCapacityDescription {
                capacityTagView.text = parking.capacityDescription
                capacityTagView.isHidden = false
            } else {
                capacityTagView.isHidden = true
            }

            reservationTagView.isHidden = parking.reservationInfo == nil
            fullTagView.isHidden = parking.reservationInfo?.status != .full && parking.vacancyInfo?.status != .full
            crowdedTagView.isHidden = parking.vacancyInfo?.status != .crowded
            vacantTagView.isHidden = parking.reservationInfo?.status != .vacant && parking.vacancyInfo?.status != .vacant
        }

        var hasSimpleCapacityDescription: Bool {
            guard let capacityDescription = parking?.capacityDescription else { return false }

            let numberOfMatches = simpleCapacityRegularExpression.numberOfMatches(
                in: capacityDescription,
                range: NSRange(0..<capacityDescription.count)
            )

            return numberOfMatches == 1
        }

        lazy var capacityTagView = TagView(textColor: .secondaryLabel, borderColor: .secondaryLabel)
        lazy var reservationTagView = TagView(text: "予約制", textColor: .white, backgroundColor: .systemGreen)
        lazy var fullTagView = TagView(text: "満車", textColor: .white, backgroundColor: .systemRed)
        lazy var crowdedTagView = TagView(text: "混雑", textColor: .white, backgroundColor: .systemOrange)
        lazy var vacantTagView = TagView(text: "空車", textColor: .white, backgroundColor: .systemBlue)
    }

    class TagView: UIView {
        let horizontalPadding: CGFloat = 4
        let verticalPadding: CGFloat = 1

        var text: String? {
            get {
                return label.text
            }

            set {
                label.text = newValue
            }
        }

        lazy var label: UILabel = {
            let label = UILabel()
            let fontMetrics = UIFontMetrics(forTextStyle: .footnote)
            label.adjustsFontForContentSizeCategory = true
            label.font = fontMetrics.scaledFont(for: UIFont.systemFont(ofSize: 11.5, weight: .semibold))
            label.textAlignment = .center
            label.textColor = .white
            return label
        }()

        private var borderColor: UIColor?

        init(text: String? = nil, textColor: UIColor? = nil, backgroundColor: UIColor? = nil, borderColor: UIColor? = nil) {
            super.init(frame: .zero)

            label.text = text
            label.textColor = textColor
            self.backgroundColor = backgroundColor
            self.borderColor = borderColor
            applyBorderColor()

            if borderColor != nil {
                layer.borderWidth = 1
            }

            clipsToBounds = true
            layer.cornerRadius = 3

            addSubview(label)

            label.translatesAutoresizingMaskIntoConstraints = false

            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: horizontalPadding),
                trailingAnchor.constraint(equalTo: label.trailingAnchor, constant: horizontalPadding),
                label.topAnchor.constraint(equalTo: topAnchor, constant: verticalPadding),
                bottomAnchor.constraint(equalTo: label.bottomAnchor, constant: verticalPadding),
            ])
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
            super.traitCollectionDidChange(previousTraitCollection)

            if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                applyBorderColor()
            }
        }

        func applyBorderColor() {
            guard let borderColor = borderColor else { return }
            layer.borderColor = borderColor.cgColor
        }
    }
}

fileprivate extension UIColor {
    func blend(with other: UIColor, ratio: CGFloat) -> UIColor? {
        var red1: CGFloat = 0, red2: CGFloat = 0
        var green1: CGFloat = 0, green2: CGFloat = 0
        var blue1: CGFloat = 0, blue2: CGFloat = 0
        var alpha1: CGFloat = 0, alpha2: CGFloat = 0

        if getRed(&red1, green: &green1, blue: &blue1, alpha: &alpha1),
           other.getRed(&red2, green: &green2, blue: &blue2, alpha: &alpha2)
        {

            let selfRatio = (ratio...ratio).clamped(to: 0...1).lowerBound
            let otherRatio = 1 - selfRatio

            return UIColor(
                red: red1 * selfRatio + red2 * otherRatio,
                green: green1 * selfRatio + green2 * otherRatio,
                blue: blue1 * selfRatio + blue2 * otherRatio,
                alpha: alpha1 * selfRatio + alpha2 * otherRatio
            )
        } else {
            return nil
        }
    }
}

class WeakReferenceArray<Element: AnyObject> {
    private let pointerArray = NSPointerArray.weakObjects()

    var objects: [Element] {
        return (pointerArray.allObjects as? [Element]) ?? []
    }

    var count: Int {
        return objects.count
    }

    var isEmpty: Bool {
        return count == 0
    }

    func append(_ newElement: Element) {
        let pointer = Unmanaged.passUnretained(newElement).toOpaque()
        pointerArray.addPointer(pointer)
    }

    func append<S>(contentsOf newElements: S) where Element == S.Element, S : Sequence {
        for newElement in newElements {
            append(newElement)
        }
    }
}
