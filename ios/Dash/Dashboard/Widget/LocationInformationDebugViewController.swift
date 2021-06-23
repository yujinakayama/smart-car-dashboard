//
//  LocationInformationDebugViewController.swift
//  Dash
//
//  Created by Yuji Nakayama on 2021/06/23.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import UIKit
import MapKit
import DirectionalUserLocationAnnotationView

class LocationInformationDebugViewController: UIViewController, MKMapViewDelegate, LocationInformationWidgetViewControllerDelegate, UIGestureRecognizerDelegate {
    lazy var mapView: MKMapView = {
        let mapView = MKMapView()
        mapView.delegate = self
        mapView.showsUserLocation = true
        mapView.isPitchEnabled = false
        mapView.isRotateEnabled = false
        mapView.register(DirectionalUserLocationAnnotationView.self, forAnnotationViewWithReuseIdentifier: "DirectionalUserLocationAnnotationView")
        return mapView
    }()

    lazy var locationAccuracyLabel: UILabel = {
        let label = UILabel()
        label.textColor = .label
        label.font = .systemFont(ofSize: 16, weight: .medium)
        return label
    }()

    var recentLocations: [CLLocation] = []
    var recentLocationsOverlay: MKOverlay?

    var currentPlace: OpenCage.Place? {
        didSet {
            if let currentPlaceOverlay = currentPlaceOverlay {
                mapView.removeOverlay(currentPlaceOverlay)
            }

            currentPlaceOverlay = nil

            if let currentPlace = currentPlace, let overlay = makeOverlay(for: currentPlace) {
                currentPlaceOverlay = overlay
                mapView.addOverlay(overlay)
            }

            updateNavigationBarTitle()
        }
    }

    var currentPlaceOverlay: MKOverlay?

    var previousPlace: OpenCage.Place? {
        didSet {
            if let previousPlaceOverlay = previousPlaceOverlay {
                mapView.removeOverlay(previousPlaceOverlay)
            }

            previousPlaceOverlay = nil

            if let previousPlace = previousPlace, let overlay = makeOverlay(for: previousPlace) {
                previousPlaceOverlay = overlay
                mapView.addOverlay(overlay)
            }
        }
    }

    var previousPlaceOverlay: MKOverlay?

    var hasZoomedToUserLocation = false

    let gestureRecognizer = UIGestureRecognizer()
    var userTrackingModeRestorationTimer: Timer?

    lazy var doneBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done))

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.rightBarButtonItem = doneBarButtonItem

        gestureRecognizer.delegate = self
        mapView.addGestureRecognizer(gestureRecognizer)

        configureSubviews()
    }

    func configureSubviews() {
        view.addSubview(mapView)

        mapView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: mapView.trailingAnchor),
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            view.bottomAnchor.constraint(equalTo: mapView.bottomAnchor),
        ])

        view.addSubview(locationAccuracyLabel)

        locationAccuracyLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            view.safeAreaLayoutGuide.trailingAnchor.constraint(equalTo: locationAccuracyLabel.trailingAnchor, constant: 12),
            locationAccuracyLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
        ])
    }

    deinit {
        // > Before releasing an MKMapView object for which you have set a delegate,
        // > remember to set that object’s delegate property to nil.
        // https://developer.apple.com/documentation/mapkit/mkmapviewdelegate
        mapView.delegate = nil
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        mapView.setUserTrackingMode(.follow, animated: false)
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation {
            return mapView.dequeueReusableAnnotationView(withIdentifier: "DirectionalUserLocationAnnotationView", for: annotation)
        } else {
            return nil
        }
    }

    func locationInformationWidget(_ viewController: LocationInformationWidgetViewController, didUpdateCurrentLocation location: CLLocation) {
        appendToRecentLocations(location)

        if let recentLocationsOverlay = recentLocationsOverlay {
            mapView.removeOverlay(recentLocationsOverlay)
        }

        mapView.addOverlay(makeOverlayForRecentLocations())

        locationAccuracyLabel.text = String(format: "Location Accuracy: %.1f", location.horizontalAccuracy)
    }

    func locationInformationWidget(_ viewController: LocationInformationWidgetViewController, didUpdateCurrentPlace place: OpenCage.Place?) {
        previousPlace = currentPlace
        currentPlace = place
    }

    func appendToRecentLocations(_ location: CLLocation) {
        recentLocations.append(location)
        recentLocations = Array(recentLocations.drop { $0.timestamp.distance(to: location.timestamp) > 30 })
    }

    func updateNavigationBarTitle() {
        guard let place = currentPlace else {
            navigationItem.title = nil
            return
        }

        let roadName = LocationInformationWidgetViewController.RoadName(place: place)

        if let popularName = roadName.popularName, let canonicalName = roadName.canonicalRoadName {
            navigationItem.title = "\(popularName) - \(canonicalName)"
        } else if let canonicalName = roadName.canonicalRoadName {
            navigationItem.title = canonicalName
        } else {
            navigationItem.title = roadName.unnumberedRouteName
        }
    }

    func makeOverlayForRecentLocations() -> MKOverlay {
        let coordinates = recentLocations.map { $0.coordinate }
        return MKPolyline(coordinates: coordinates, count: coordinates.count)
    }

    func makeOverlay(for place: OpenCage.Place) -> MKOverlay? {
        let region = place.region.extended(by: LocationInformationWidgetViewController.regionExtensionDistance)

        let northeast = region.northeast
        let southwest = region.southwest

        let northwest = CLLocationCoordinate2D(latitude: northeast.latitude, longitude: southwest.longitude)
        let southeast = CLLocationCoordinate2D(latitude: southwest.latitude, longitude: northeast.longitude)

        let coordinates = [northeast, southeast, southwest, northwest]
        return MKPolygon(coordinates: coordinates, count: coordinates.count)
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        switch overlay {
        case let polygon as MKPolygon:
            let baseColor: UIColor = (polygon === currentPlaceOverlay) ? .systemBlue : .systemGray
            let renderer = MKPolygonRenderer(polygon: polygon)
            renderer.strokeColor = baseColor.withAlphaComponent(0.6)
            renderer.fillColor = baseColor.withAlphaComponent(0.3)
            renderer.lineWidth = 1
            return renderer
        case let polyline as MKPolyline:
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = .systemBlue
            renderer.lineWidth = 4
            return renderer
        default:
            return MKOverlayRenderer()
        }
    }

    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        if let userLocationView = mapView.view(for: userLocation) as? DirectionalUserLocationAnnotationView {
            userLocationView.updateDirection(animated: true)
        }

        if !hasZoomedToUserLocation {
            mapView.region = MKCoordinateRegion(center: userLocation.coordinate, latitudinalMeters: 800, longitudinalMeters: 800)
            hasZoomedToUserLocation = true
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        mapViewDidTouch()
        return false
    }

    private func mapViewDidTouch() {
        userTrackingModeRestorationTimer?.invalidate()

        userTrackingModeRestorationTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self] (timer) in
            guard let self = self else { return }
            if self.mapView.userTrackingMode == .follow { return }
            self.mapView.setUserTrackingMode(.follow, animated: true)
            self.userTrackingModeRestorationTimer = nil
        }
    }

    @objc func done() {
        dismiss(animated: true)
    }
}
