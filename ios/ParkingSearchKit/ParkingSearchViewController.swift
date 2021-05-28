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
import DirectionalUserLocationAnnotationView

open class ParkingSearchViewController: UIViewController {
    open var destination: MKMapItem! {
        didSet {
            if isViewLoaded {
                applyDestination()
            }
        }
    }

    var destinationCoordinate: CLLocationCoordinate2D {
        return destination.placemark.coordinate
    }

    lazy var mapView: MKMapView = {
        let mapView = MKMapView()

        mapView.delegate = self

        mapView.isPitchEnabled = false
        mapView.isRotateEnabled = false
        mapView.showsScale = true
        mapView.showsTraffic = true
        mapView.showsUserLocation = true

        mapView.pointOfInterestFilter = MKPointOfInterestFilter(including: [.parking])

        mapView.register(DirectionalUserLocationAnnotationView.self, forAnnotationViewWithReuseIdentifier: "DirectionalUserLocationAnnotationView")
        mapView.register(MKPinAnnotationView.self, forAnnotationViewWithReuseIdentifier: "MKPinAnnotationView")

        return mapView
    }()

    lazy var controlView: UIView = {
        let view = UIView()

        let visualEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .regular))

        let stackView = UIStackView(arrangedSubviews: [
            controlViewLeftMarginView,
            entranceDatePicker,
            conjunctionLabel,
            timeDurationPicker,
            controlViewRightMarginView,
        ])

        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.distribution = .fill

        view.addSubview(visualEffectView)
        view.addSubview(stackView)

        view.subviews.forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        NSLayoutConstraint.activate([
            visualEffectView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor),
            visualEffectView.topAnchor.constraint(equalTo: view.topAnchor),
            view.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor),
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.widthAnchor.constraint(lessThanOrEqualToConstant: 400),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor).withPriority(.defaultLow),
            view.trailingAnchor.constraint(equalTo: stackView.trailingAnchor).withPriority(.defaultLow),
            stackView.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor),
            view.layoutMarginsGuide.bottomAnchor.constraint(equalTo: stackView.bottomAnchor),
        ])

        return view
    }()

    lazy var entranceDatePicker: UIDatePicker = {
        let datePicker = UIDatePicker()
        datePicker.datePickerMode = .time
        datePicker.minuteInterval = 10
        datePicker.preferredDatePickerStyle = .inline
        datePicker.locale = Locale(identifier: "en_GB")
        datePicker.addTarget(self, action: #selector(searchParkings), for: .valueChanged)
        return datePicker
    }()

    lazy var conjunctionLabel: UILabel = {
        let label = UILabel()
        label.text = "から"
        label.adjustsFontForContentSizeCategory = true
        label.font = UIFont.preferredFont(forTextStyle: .title3)
        label.textAlignment = .center
        return label
    }()

    lazy var timeDurationPicker: TimeDurationPicker = {
        let timeDurationPicker = TimeDurationPicker()

        timeDurationPicker.durations = [
            30,
            60,
            120,
            180,
            360,
            720,
            1440
        ].map { TimeInterval($0 * 60) }

        timeDurationPicker.selectRow(1, animated: false)

        timeDurationPicker.addTarget(self, action: #selector(searchParkings), for: .valueChanged)

        timeDurationPicker.setContentHuggingPriority(.required, for: .horizontal)
        timeDurationPicker.setContentHuggingPriority(.required, for: .vertical)

        return timeDurationPicker
    }()

    lazy var controlViewLeftMarginView: UIView = {
        let view = UIView()

        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: 20),
            view.heightAnchor.constraint(equalTo: view.widthAnchor),
        ])

        return view
    }()

    lazy var controlViewRightMarginView: UIView = {
        let view = UIView()

        view.addSubview(activityIndicatorView)
        activityIndicatorView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: 20),
            view.heightAnchor.constraint(equalTo: view.widthAnchor),
            activityIndicatorView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicatorView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])

        return view
    }()

    lazy var activityIndicatorView = UIActivityIndicatorView()

    let locationManager = CLLocationManager()

    let ppparkClient = PPParkClient(clientKey: "IdkUdfal673kUdj00")

    lazy var destinationAnnotation: MKPointAnnotation = {
        let annotation = MKPointAnnotation()
        annotation.coordinate = destinationCoordinate
        annotation.title = destination.name
        return annotation
    }()

    var currentSearchTask: URLSessionTask?

    open override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(mapView)
        view.addSubview(controlView)

        view.subviews.forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        NSLayoutConstraint.activate([
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: mapView.trailingAnchor),
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            view.bottomAnchor.constraint(equalTo: mapView.bottomAnchor),
            controlView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: controlView.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: controlView.bottomAnchor),
        ])

        navigationItem.largeTitleDisplayMode = .never

        locationManager.requestWhenInUseAuthorization()

        if destination != nil {
            applyDestination()
        }
    }

    open override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        currentSearchTask?.cancel()
    }

    deinit {
        // > Before releasing an MKMapView object for which you have set a delegate,
        // > remember to set that object’s delegate property to nil.
        // https://developer.apple.com/documentation/mapkit/mkmapviewdelegate
        mapView.delegate = nil
    }

    func applyDestination() {
        if let locationName = destination.name {
            navigationItem.title = "”\(locationName)“ 周辺の駐車場"
        } else {
            navigationItem.title = "周辺の駐車場"
        }

        showDestination()

        calculateExpectedTravelTime { (travelTime) in
            DispatchQueue.main.async {
                if let travelTime = travelTime {
                    self.entranceDatePicker.date = Date() + travelTime
                }

                self.searchParkings()
            }
        }
    }

    func showDestination() {
        mapView.addAnnotation(destinationAnnotation)

        let region = MKCoordinateRegion(center: destinationCoordinate, latitudinalMeters: 500, longitudinalMeters: 500)
        mapView.setRegion(region, animated: false)
    }

    func calculateExpectedTravelTime(completion: @escaping (TimeInterval?) -> Void) {
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
                print(error)
            }

            completion(response?.routes.first?.expectedTravelTime)
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
                print(error)

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
        let openParkings = parkings.filter { !$0.isClosed }
        addParkings(openParkings)
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

    @objc func openReservationPage() {
        guard let parking = (mapView.selectedAnnotations.first as? ParkingAnnotation)?.parking else { return }
        guard let reservationURL = parking.reservationInfo?.url else { return }

        let webViewController = WebViewController(url: reservationURL)
        webViewController.navigationItem.title = parking.name

        let navigationController = UINavigationController(rootViewController: webViewController)
        navigationController.isToolbarHidden = false
        present(navigationController, animated: true)
    }

    open override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
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
    open func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        switch annotation {
        case let userLocation as MKUserLocation:
            return viewForUserLocation(userLocation)
        case let parkingAnnotation as ParkingAnnotation:
            return viewForParkingAnnotation(parkingAnnotation)
        default:
            return viewForOtherAnnotation(annotation)
        }
    }

    open func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
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
            view.callout.reservationButton.addTarget(self, action: #selector(openReservationPage), for: .touchUpInside)
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
