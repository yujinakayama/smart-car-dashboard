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

        mapView.pointOfInterestFilter = MKPointOfInterestFilter.excludingAll

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

    typealias RequestContext = (place: OpenCage.Place, location: CLLocation, updateReason: LocationInformationWidgetViewController.UpdateReason)

    var currentRequestContext: RequestContext? {
        didSet {
            if let currentPlaceOverlay = currentPlaceOverlay {
                mapView.removeOverlay(currentPlaceOverlay)
            }

            currentPlaceOverlay = nil

            if let currentRequestLocationOverlay = currentRequestLocationOverlay {
                mapView.removeOverlay(currentRequestLocationOverlay)
            }

            currentRequestLocationOverlay = nil

            if let currentPlace = currentPlace {
                let overlay = makeOverlay(for: currentPlace)
                currentPlaceOverlay = overlay
                mapView.insertOverlay(overlay, at: 11)
            }

            if let location = currentRequestContext?.location {
                let overlay = makeOverlay(for: location)
                currentRequestLocationOverlay = overlay
                mapView.insertOverlay(overlay, at: 21)
            }

            updateNavigationBarTitle()
        }
    }

    var currentPlace: OpenCage.Place? {
        return currentRequestContext?.place
    }

    var currentPlaceOverlay: MKOverlay?

    var currentRequestLocationOverlay: MKOverlay?

    var previousRequestContext: RequestContext? {
        didSet {
            if let previousPlaceOverlay = previousPlaceOverlay {
                mapView.removeOverlay(previousPlaceOverlay)
            }

            previousPlaceOverlay = nil

            if let previousRequestLocationOverlay = previousRequestLocationOverlay {
                mapView.removeOverlay(previousRequestLocationOverlay)
            }

            previousRequestLocationOverlay = nil

            if let previousPlace = previousPlace {
                let overlay = makeOverlay(for: previousPlace)
                previousPlaceOverlay = overlay
                mapView.insertOverlay(overlay, at: 10)
            }

            if let location = previousRequestContext?.location {
                let overlay = makeOverlay(for: location)
                previousRequestLocationOverlay = overlay
                mapView.insertOverlay(overlay, at: 20)
            }
        }
    }

    var previousPlace: OpenCage.Place? {
        return previousRequestContext?.place
    }

    var previousPlaceOverlay: MKOverlay?

    var previousRequestLocationOverlay: MKOverlay?

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

        mapView.insertOverlay(makeOverlayForRecentLocations(), at: 1)

        locationAccuracyLabel.text = String(format: "Location Accuracy: %.1f", location.horizontalAccuracy)
    }

    func locationInformationWidget(_ viewController: LocationInformationWidgetViewController, didUpdateCurrentPlace place: OpenCage.Place, for location: CLLocation, reason: LocationInformationWidgetViewController.UpdateReason) {
        previousRequestContext = currentRequestContext
        currentRequestContext = (place: place, location: location, updateReason: reason)
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

        navigationItem.title = roadName(for: place)
    }

    func makeOverlayForRecentLocations() -> MKOverlay {
        let coordinates = recentLocations.map { $0.coordinate }
        return MKPolyline(coordinates: coordinates, count: coordinates.count)
    }

    func makeOverlay(for place: OpenCage.Place) -> MKOverlay {
        let region = place.region.extended(by: LocationInformationWidgetViewController.regionExtensionDistance)

        let northeast = region.northeast
        let southwest = region.southwest

        let northwest = CLLocationCoordinate2D(latitude: northeast.latitude, longitude: southwest.longitude)
        let southeast = CLLocationCoordinate2D(latitude: southwest.latitude, longitude: northeast.longitude)

        let coordinates = [northeast, southeast, southwest, northwest]
        return MKPolygon(coordinates: coordinates, count: coordinates.count)
    }

    func makeOverlay(for location: CLLocation) -> MKOverlay {
        return MKCircle(center: location.coordinate, radius: 6)
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        switch overlay {
        case let polygon as MKPolygon:
            guard let place = (polygon === currentPlaceOverlay) ? currentPlace : previousPlace else { break }
            let baseColor: UIColor = (polygon === currentPlaceOverlay) ? .systemBlue : .systemGray
            return PlaceRenderer(polygon: polygon, place: place, baseColor: baseColor)
        case let polyline as MKPolyline:
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = .secondaryLabel
            renderer.lineWidth = 4
            return renderer
        case let circle as MKCircle:
            guard let requestContext = (circle === currentRequestLocationOverlay) ? currentRequestContext : previousRequestContext else { break }
            let baseColor: UIColor = (circle === currentRequestLocationOverlay) ? .systemBlue : .systemGray
            return RequestLocationRenderer(circle: circle, requestContext: requestContext, baseColor: baseColor)
        default:
            break
        }

        return MKOverlayRenderer()
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

fileprivate class PlaceRenderer: MKPolygonRenderer {
    let place: OpenCage.Place
    let baseColor: UIColor

    init(polygon: MKPolygon, place: OpenCage.Place, baseColor: UIColor) {
        self.place = place
        self.baseColor = baseColor

        super.init(polygon: polygon)

        strokeColor = baseColor.withAlphaComponent(0.6)
        fillColor = baseColor.withAlphaComponent(0.3)
        lineWidth = 1
    }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        super.draw(mapRect, zoomScale: zoomScale, in: context)

        guard let roadName = roadName(for: place) as NSString? else { return }

        let font = UIFont.systemFont(ofSize: 50 / zoomScale, weight: .semibold)

        let shadow = NSShadow()
        shadow.shadowColor = UIColor.systemBackground
        shadow.shadowOffset = .zero
        shadow.shadowBlurRadius = 8 / zoomScale

        var point = point(for: overlay.boundingMapRect.origin)
        point.y -= height(of: roadName, with: font) * 1.1

        UIGraphicsPushContext(context)

        roadName.draw(at: point, withAttributes: [
            .font: font,
            .foregroundColor: baseColor,
            .shadow: shadow
        ])

        UIGraphicsPopContext()
    }
}

fileprivate class RequestLocationRenderer: MKCircleRenderer {
    let requestContext: LocationInformationDebugViewController.RequestContext
    let baseColor: UIColor

    init(circle: MKCircle, requestContext: LocationInformationDebugViewController.RequestContext, baseColor: UIColor) {
        self.requestContext = requestContext
        self.baseColor = baseColor
        super.init(circle: circle)
        fillColor = baseColor
    }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        super.draw(mapRect, zoomScale: zoomScale, in: context)

        let text = requestContext.updateReason.description as NSString

        let font = UIFont.systemFont(ofSize: 35 / zoomScale, weight: .semibold)

        let shadow = NSShadow()
        shadow.shadowColor = UIColor.systemBackground
        shadow.shadowOffset = .zero
        shadow.shadowBlurRadius = 8 / zoomScale

        let rect = rect(for: overlay.boundingMapRect)
        let point = CGPoint(x: rect.maxX + 30 / zoomScale, y: rect.midY - height(of: text, with: font) / 2)

        UIGraphicsPushContext(context)

        text.draw(at: point, withAttributes: [
            .font: font,
            .foregroundColor: baseColor,
            .shadow: shadow
        ])

        UIGraphicsPopContext()
    }
}

fileprivate func roadName(for place: OpenCage.Place) -> String? {
    let roadName = LocationInformationWidgetViewController.RoadName(place: place)

    if let popularName = roadName.popularName, let canonicalName = roadName.canonicalRoadName {
        return "\(popularName) - \(canonicalName)"
    } else if let canonicalName = roadName.canonicalRoadName {
        return canonicalName
    } else {
        return roadName.unnumberedRouteName
    }
}

fileprivate func height(of text: NSString, with font: UIFont) -> CGFloat {
    let infiniteSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

    let boundingRect = text.boundingRect(
        with: infiniteSize,
        options: .usesLineFragmentOrigin,
        attributes: [.font: font],
        context: nil
    )

    return ceil(boundingRect.height)
}
