//
//  ParkingSearchViewController.swift
//  Dash
//
//  Created by Yuji Nakayama on 2021/02/27.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation

class ParkingSearchViewController: UIViewController {
    var destination: Location!

    var destinationCoordinate: CLLocationCoordinate2D {
        return destination.coordinate.clLocationCoordinate2D
    }

    @IBOutlet weak var mapView: MKMapView!

    @IBOutlet weak var controlView: UIView!

    @IBOutlet weak var entranceDatePicker: UIDatePicker!
    @IBOutlet weak var timeDurationPicker: TimeDurationPicker!
    @IBOutlet weak var activityIndicatorView: UIActivityIndicatorView!

    let locationManager = CLLocationManager()

    let ppparkClient = PPParkClient(clientKey: "IdkUdfal673kUdj00")

    let markerBaseColor = UIColor(named: "Location Icon Color")!

    lazy var destinationAnnotation: MKPointAnnotation = {
        let annotation = MKPointAnnotation()
        annotation.coordinate = destinationCoordinate
        annotation.title = destination.name
        return annotation
    }()

    var currentSearchTask: URLSessionTask?

    override func viewDidLoad() {
        super.viewDidLoad()

        if let locationName = destination.name {
            navigationItem.title = "”\(locationName)“ 周辺の駐車場"
        } else {
            navigationItem.title = "周辺の駐車場"
        }

        mapView.delegate = self
        mapView.register(DirectionalUserLocationAnnotationView.self, forAnnotationViewWithReuseIdentifier: "DirectionalUserLocationAnnotationView")
        mapView.register(MKPinAnnotationView.self, forAnnotationViewWithReuseIdentifier: "MKPinAnnotationView")
        mapView.pointOfInterestFilter = MKPointOfInterestFilter(including: [.parking])

        timeDurationPicker.durations = [
            30,
            60,
            120,
            180,
            360,
            720,
            1440
        ].map { TimeInterval($0 * 60) }

        entranceDatePicker.addTarget(self, action: #selector(searchParkings), for: .valueChanged)
        timeDurationPicker.addTarget(self, action: #selector(searchParkings), for: .valueChanged)

        locationManager.requestWhenInUseAuthorization()

        showDestination()

        calculateExpectedTravelTime { (travelTime) in
            DispatchQueue.main.async {
                self.entranceDatePicker.date = Date() + travelTime
                self.searchParkings()
            }
        }
    }

    func showDestination() {
        mapView.addAnnotation(destinationAnnotation)

        let region = MKCoordinateRegion(center: destinationCoordinate, latitudinalMeters: 500, longitudinalMeters: 500)
        mapView.setRegion(region, animated: false)
    }

    func calculateExpectedTravelTime(completion: @escaping (TimeInterval) -> Void) {
        activityIndicatorView.startAnimating()

        let request = MKDirections.Request()
        request.source = MKMapItem.forCurrentLocation()
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destinationCoordinate))
        request.transportType = .automobile

        MKDirections(request: request).calculate { (response, error) in
            DispatchQueue.main.async {
                self.activityIndicatorView.stopAnimating()
            }

            if let error = error {
                logger.error(error)
                return
            }

            if let route = response?.routes.first {
                completion(route.expectedTravelTime)
            }
        }
    }

    @objc func searchParkings() {
        currentSearchTask?.cancel()

        removeParkings()

        guard let timeDuration = timeDurationPicker.selectedDuration else { return }

        activityIndicatorView.startAnimating()

        currentSearchTask = ppparkClient.searchParkings(
            around: destinationCoordinate,
            entranceDate: entranceDatePicker.date,
            exitDate: entranceDatePicker.date + timeDuration
        ) { [weak self] (result) in
            guard let self = self else { return }

            var isCancelled = false

            switch result {
            case .success(let parkings):
                DispatchQueue.main.async {
                    self.showParkings(parkings)
                }
            case .failure(let error):
                logger.error(error)

                if let urlError = error as? URLError, urlError.code == .cancelled {
                    isCancelled = true
                }
            }

            if !isCancelled {
                DispatchQueue.main.async {
                    self.activityIndicatorView.stopAnimating()
                }
            }
        }
    }

    func showParkings(_ parkings: [Parking]) {
        addParkings(parkings)
        mapView.showAnnotations(parkingAnnotations + [destinationAnnotation], animated: true)
        selectBestParking()
    }

    func addParkings(_ parkings: [Parking]) {
        let annotations = parkings.map { ParkingAnnotation($0) }
        mapView.addAnnotations(annotations)
    }

    func removeParkings() {
        mapView.removeAnnotations(parkingAnnotations)
    }

    func selectBestParking() {
        let cheapstParkingAnnotations = parkingAnnotations.filter { $0.parking.rank == 1 }
        let bestParkingAnnotation = cheapstParkingAnnotations.min { $0.parking.distance < $1.parking.distance }

        if let bestParkingAnnotation = bestParkingAnnotation {
            mapView.selectAnnotation(bestParkingAnnotation, animated: true)
        }
    }

    var parkingAnnotations: [ParkingAnnotation] {
        mapView.annotations.filter { $0 is ParkingAnnotation } as! [ParkingAnnotation]
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateControlViewShadowColor()
        }
    }

    func updateControlViewShadowColor() {
        if traitCollection.userInterfaceStyle == .dark {
            controlView.layer.shadowColor = UIColor.black.cgColor
            controlView.layer.shadowOpacity = 0.15
        } else {
            controlView.layer.shadowColor = UIColor.black.cgColor
            controlView.layer.shadowOpacity = 0.05
        }
    }
}

extension ParkingSearchViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        switch annotation {
        case let userLocation as MKUserLocation:
            return viewForUserLocation(userLocation)
        case let parkingAnnotation as ParkingAnnotation:
            return viewForParkingAnnotation(parkingAnnotation)
        default:
            return viewForOtherAnnotation(annotation)
        }
    }

    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        guard let userLocationView = mapView.view(for: userLocation) as? DirectionalUserLocationAnnotationView else { return }
        userLocationView.updateDirection(animated: true)
    }

    private func viewForUserLocation(_ annotation: MKUserLocation) -> MKAnnotationView {
        return mapView.dequeueReusableAnnotationView(withIdentifier: "DirectionalUserLocationAnnotationView", for: annotation)
    }

    private func viewForParkingAnnotation(_ annotation: ParkingAnnotation) -> MKAnnotationView {
        if let view = mapView.dequeueReusableAnnotationView(withIdentifier: "MKMarkerAnnotationView") as? ParkingAnnotationView {
            view.annotation = annotation
            return view
        } else {
            return ParkingAnnotationView(annotation: annotation, reuseIdentifier: "MKMarkerAnnotationView")
        }
    }

    private func viewForOtherAnnotation(_ annotation: MKAnnotation) -> MKAnnotationView {
        let view = mapView.dequeueReusableAnnotationView(withIdentifier: "MKPinAnnotationView", for: annotation) as! MKPinAnnotationView
        view.canShowCallout = true
        view.displayPriority = .required
        return view
    }
}

class ParkingAnnotation: NSObject, MKAnnotation {
    let parking: Parking

    init(_ parking: Parking) {
        self.parking = parking
        super.init()
    }

    var coordinate: CLLocationCoordinate2D {
        return parking.coordinate
    }

    var title: String? {
        if let price = parking.price {
            return "¥\(price)"
        } else if parking.isClosed {
            return "営業時間外"
        } else {
            return "料金不明"
        }
    }

    var subtitle: String? {
        return parking.name
    }
}

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
                glyphImage = UIImage(systemName: "xmark")
            } else {
                glyphImage = UIImage(systemName: "questionmark")
            }

            markerTintColor = .systemGray
            zPriority = .min
        }

        callout.update()
    }
}

extension ParkingAnnotationView {
    class Callout {
        weak var annotationView: ParkingAnnotationView?

        var parking: Parking? {
            return annotationView?.parking
        }

        init(annotationView: ParkingAnnotationView) {
            self.annotationView = annotationView

            annotationView.canShowCallout = true
            annotationView.detailCalloutAccessoryView = detailView
            annotationView.rightCalloutAccessoryView = departureButton
        }

        lazy var detailView: UIView = {
            let stackView = UIStackView(arrangedSubviews: [
                nameLabel,
                rulerView,
                makeItemLabels(heading: "台数", contentLabel: capacityLabel),
                makeItemLabels(heading: "営業時間", contentLabel: openingHoursLabel),
                makeItemLabels(heading: "料金", contentLabel: priceDescriptionLabel)
            ])

            // Not arrannged
            tagListView.translatesAutoresizingMaskIntoConstraints = false
            stackView.addSubview(tagListView)

            stackView.axis = .vertical
            stackView.alignment = .fill
            stackView.distribution = .equalSpacing
            stackView.spacing = 8
            return stackView
        }()

        lazy var nameLabel = makeContentLabel(textColor: .secondaryLabel, multiline: false)

        lazy var tagListView = TagListView()
        let tagListViewConstraints = WeakReferenceArray<NSLayoutConstraint>()

        lazy var rulerView: UIView = {
            let view = UIView()
            view.backgroundColor = .tertiaryLabel
            view.heightAnchor.constraint(equalToConstant: 1.0 / UIScreen.main.scale).isActive = true
            return view
        }()

        lazy var capacityLabel = makeContentLabel()
        lazy var openingHoursLabel = makeContentLabel()
        lazy var priceDescriptionLabel = makeContentLabel()

        func makeItemLabels(heading: String, contentLabel: UILabel) -> UIView {
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
            let carImage = UIImage(systemName: "car.circle.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 42))

            let button = UIButton()
            button.setImage(carImage, for: .normal)
            button.tintColor = UIColor(named: "Departure Color")!
            button.sizeToFit()
            button.addTarget(self, action: #selector(openDirectionsInMaps), for: .touchUpInside)
            return button
        }()

        func annotationViewDidLayoutSubviews() {
            if let titleLabel = privateTitleLabel, tagListViewConstraints.isEmpty {
                // We need to reconfigure constraints when titleLabel instance is recreated
                let constraints = [
                    tagListView.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 6),
                    tagListView.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor)
                ]

                NSLayoutConstraint.activate(constraints)
                tagListViewConstraints.append(contentsOf: constraints)
            }
        }

        var privateTitleLabel: UILabel? {
            return privateCalloutView?.value(forKey: "_titleLabel") as? UILabel
        }

        var privateCalloutView: UIView? {
            var currentView: UIView? = detailView.superview

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
            guard let parking = parking else { return }

            nameLabel.text = parking.name
            capacityLabel.text = normalizeDescription(parking.capacityDescription) ?? "-"
            openingHoursLabel.text = normalizeDescription(parking.openingHoursDescription) ?? "-"
            priceDescriptionLabel.text = normalizedPriceDescription ?? "-"

            tagListView.parking = parking
        }

        func normalizeDescription(_ text: String?) -> String? {
            guard let text = text else { return nil }

            let lines = text.split(separator: "\n")
            let normalizedLines = lines.map { $0.trimmingCharacters(in: .whitespaces) }.compactMap { $0 }
            return normalizedLines.joined(separator: "\n")
        }

        var normalizedPriceDescription: String? {
            guard let parking = parking, let text = normalizeDescription(parking.priceDescription) else { return nil }

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

        @objc func openDirectionsInMaps() {
            guard let parking = parking else { return }

            let placemark = MKPlacemark(coordinate: parking.coordinate)
            let mapItem = MKMapItem(placemark: placemark)
            mapItem.name = parking.name

            mapItem.openInMaps(launchOptions: [
                MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving,
                MKLaunchOptionsMapTypeKey: Defaults.shared.mapTypeForDirections?.rawValue ?? MKMapType.standard
            ])
        }
    }
}

extension ParkingAnnotationView.Callout {
    class TagListView: UIStackView {
        var parking: Parking? {
            didSet {
                update()
            }
        }

        init() {
            super.init(frame: .zero)

            axis = .horizontal
            spacing = 6

            addArrangedSubview(reservationTagView)
            addArrangedSubview(fullTagView)
            addArrangedSubview(crowdedTagView)
            addArrangedSubview(vacantTagView)
        }

        required init(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update() {
            guard let parking = parking else { return }

            reservationTagView.isHidden = parking.reservationInfo == nil
            fullTagView.isHidden = parking.reservationInfo?.status != .full && parking.vacancyInfo?.status != .full
            crowdedTagView.isHidden = parking.vacancyInfo?.status != .crowded
            vacantTagView.isHidden = parking.reservationInfo?.status != .vacant && parking.vacancyInfo?.status != .vacant
        }

        lazy var reservationTagView = TagView(name: "予約制", color: .systemGreen)
        lazy var fullTagView = TagView(name: "満車", color: .systemRed)
        lazy var crowdedTagView = TagView(name: "混雑", color: .systemOrange)
        lazy var vacantTagView = TagView(name: "空車", color: .systemBlue)
    }

    class TagView: UIView {
        let horizontalPadding: CGFloat = 4
        let verticalPadding: CGFloat = 1

        lazy var label: UILabel = {
            let label = UILabel()
            let fontMetrics = UIFontMetrics(forTextStyle: .footnote)
            label.adjustsFontForContentSizeCategory = true
            label.font = fontMetrics.scaledFont(for: UIFont.systemFont(ofSize: 11, weight: .semibold))
            label.textAlignment = .center
            label.textColor = .white
            return label
        }()

        init(name: String, color: UIColor) {
            super.init(frame: .zero)

            backgroundColor = color
            clipsToBounds = true
            layer.cornerRadius = 3

            label.text = name

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
