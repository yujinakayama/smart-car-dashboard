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
        var view: MKMarkerAnnotationView! = mapView.dequeueReusableAnnotationView(withIdentifier: "MKMarkerAnnotationView") as? MKMarkerAnnotationView

        if view == nil {
            view = makeParkingAnnotationView(for: annotation)
        } else {
            view.annotation = annotation
        }

        if let rank = annotation.parking.rank {
            view.glyphText = "\(rank)位"
            view.markerTintColor = UIColor.link.blend(
                with: UIColor.systemGray,
                ratio: 1.0 - CGFloat(rank - 1) * 0.2
            )
            view.zPriority = MKAnnotationViewZPriority(rawValue: MKAnnotationViewZPriority.defaultUnselected.rawValue - Float(rank - 1))
        } else {
            if annotation.parking.isClosed {
                view.glyphImage = UIImage(systemName: "xmark")
            } else {
                view.glyphImage = UIImage(systemName: "questionmark")
            }

            view.markerTintColor = .systemGray
            view.zPriority = .min
        }

        return view
    }

    private func makeParkingAnnotationView(for annotation: MKAnnotation) -> MKMarkerAnnotationView {
        let view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "MKMarkerAnnotationView")
        view.canShowCallout = true
        view.animatesWhenAdded = true
        view.displayPriority = .required

        let button = UIButton()
        let carImage = UIImage(systemName: "car.circle.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 42))
        button.setImage(carImage, for: .normal)
        button.addTarget(self, action: #selector(departureButtonDidTap), for: .touchUpInside)
        button.tintColor = UIColor(named: "Departure Color")!
        button.sizeToFit()
        view.rightCalloutAccessoryView = button

        return view
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
