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

    @objc func departureButtonDidTap() {
        guard let selectedParking = (mapView.selectedAnnotations.first as? ParkingAnnotation)?.parking else { return }
        openDirectionsInMaps(to: selectedParking)
    }

    func openDirectionsInMaps(to parking: Parking) {
        let placemark = MKPlacemark(coordinate: parking.coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = parking.name

        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving,
            MKLaunchOptionsMapTypeKey: Defaults.shared.mapTypeForDirections?.rawValue ?? MKMapType.standard
        ])
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
            let view = ParkingAnnotationView(annotation: annotation, reuseIdentifier: "MKMarkerAnnotationView")
            view.departureButton.addTarget(self, action: #selector(departureButtonDidTap), for: .touchUpInside)
            return view
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

    lazy var departureButton: UIButton = {
        let carImage = UIImage(systemName: "car.circle.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 42))

        let button = UIButton()
        button.setImage(carImage, for: .normal)
        button.tintColor = UIColor(named: "Departure Color")!
        button.sizeToFit()
        return button
    }()

    lazy var detailView: UIView = {
        let view = UIStackView(arrangedSubviews: [
            nameLabel,
            makeRulerView(),
            makeItemLabels(heading: "台数", contentLabel: capacityLabel),
            makeItemLabels(heading: "営業時間", contentLabel: openingHoursLabel),
            makeItemLabels(heading: "料金", contentLabel: priceDescriptionLabel)
        ])

        view.axis = .vertical
        view.alignment = .fill
        view.distribution = .equalSpacing
        view.spacing = 8
        return view
    }()

    lazy var nameLabel = makeContentLabel()
    lazy var capacityLabel = makeContentLabel()
    lazy var openingHoursLabel = makeContentLabel()
    lazy var priceDescriptionLabel = makeContentLabel()

    func makeItemLabels(heading: String, contentLabel: UILabel) -> UIView {
        let headinglabel = UILabel()
        headinglabel.text = heading
        headinglabel.textColor = .secondaryLabel

        let stackView = UIStackView(arrangedSubviews: [headinglabel, contentLabel])
        stackView.axis = .vertical
        stackView.distribution = .fill
        return stackView
    }

    func makeContentLabel() -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        return label
    }

    func makeRulerView() -> UIView {
        let view = UIView()
        view.backgroundColor = .tertiaryLabel
        view.heightAnchor.constraint(equalToConstant: 1.0 / UIScreen.main.scale).isActive = true
        return view
    }

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)

        canShowCallout = true
        animatesWhenAdded = true
        displayPriority = .required
        rightCalloutAccessoryView = departureButton
        detailCalloutAccessoryView = detailView

        update()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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

        nameLabel.text = parking.name
        capacityLabel.text = normalizeDescription(parking.capacityDescription) ?? "-"
        openingHoursLabel.text = normalizeDescription(parking.openingHoursDescription) ?? "-"
        priceDescriptionLabel.text = normalizedPriceDescription ?? "-"
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
