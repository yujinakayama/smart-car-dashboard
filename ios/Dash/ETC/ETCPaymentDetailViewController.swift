//
//  DetailViewController.swift
//  ETC
//
//  Created by Yuji Nakayama on 2019/05/28.
//  Copyright © 2019 Yuji Nakayama. All rights reserved.
//

import UIKit
import MapKit

class ETCPaymentDetailViewController: UIViewController, MKMapViewDelegate {
    @IBOutlet weak var mapView: MKMapView!

    var payment: ETCPaymentManagedObject? {
        didSet {
            configureView()
        }
    }

    var entranceMapItem: MKMapItem?
    var exitMapItem: MKMapItem?

    let activityIndicator = UIActivityIndicatorView(style: .medium)

    let annotationViewIdentifier = "AnnotationView"
    var hasInitiallyZoomedToUserLocation = false

    override func viewDidLoad() {
        super.viewDidLoad()

        mapView.delegate = self
        mapView.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: annotationViewIdentifier)

        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: activityIndicator)

        configureView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        mapView.showsUserLocation = true
    }

    override func viewDidDisappear(_ animated: Bool) {
        // When launching the app with the compact width size class,
        // splitViewController(_:collapseSecondary:onto:) is called and if we return true from that
        // a DetailViewController instance's view won't be loaded
        // (i.e. neither loadView() nor viewDidLoad() is called)
        // but viewDidDisapper() will be called :(
        if mapView != nil {
            mapView.showsUserLocation = false
        }
        super.viewDidDisappear(animated)
    }

    func configureView() {
        showNavigationTitle()

        activityIndicator.startAnimating()
        fetchEntranceAndExitLocation { [weak self] (entrance, exit) in
            guard let self = self else { return }

            self.activityIndicator.stopAnimating()

            guard entrance != nil && exit != nil else {
                self.clearMapView()
                return
            }

            self.showRoute(source: entrance!, destination: exit!)
        }
    }

    private func showNavigationTitle() {
        guard let entrance = payment?.entranceTollbooth, let exit = payment?.exitTollbooth else {
            navigationItem.title = nil
            return
        }

        var components: [String?] = [
            entrance.road.abbreviatedName,
            entrance.road.routeName,
            entrance.name
        ]

        if entrance != exit {
            components.append("-")

            if entrance.road != exit.road {
                components.append(exit.road.abbreviatedName)
                components.append(exit.road.routeName)
            }

            components.append(exit.name)
        }

        navigationItem.title = components.compactMap { $0 }.joined(separator: " ")
    }

    private func fetchEntranceAndExitLocation(completionHandler: @escaping (MKMapItem?, MKMapItem?) -> Void) {
        guard let entrance = payment?.entranceTollbooth, let exit = payment?.exitTollbooth else {
            completionHandler(nil, nil)
            return
        }

        let group = DispatchGroup()

        group.enter()
        mapItem(for: entrance) { [weak self] (mapItem) in
            self?.entranceMapItem = mapItem
            group.leave()
        }

        group.enter()
        mapItem(for: exit) { [weak self] (mapItem) in
            self?.exitMapItem = mapItem
            group.leave()
        }

        group.notify(queue: .main, work: DispatchWorkItem() { [weak self] in
            guard let self = self else { return }
            completionHandler(self.entranceMapItem, self.exitMapItem)
        })
    }

    private func showRoute(source: MKMapItem, destination: MKMapItem) {
        routeBetween(source: entranceMapItem!, destination: exitMapItem!) { [weak self] (route) in
            guard let self = self else { return }

            self.clearMapView()
            self.showAnnotations(entrance: source, exit: destination)

            guard route != nil else { return }

            self.mapView.addOverlay(route!.polyline)
            self.mapView.setVisibleMapRect(route!.polyline.boundingMapRect, edgePadding: self.routeRectPadding, animated: true)
        }
    }

    private func showAnnotations(entrance: MKMapItem, exit: MKMapItem) {
        [entrance, exit].forEach { (mapItem) in
            let annotation = MKPointAnnotation()
            annotation.title = mapItem.name
            annotation.subtitle = mapItem == entrance ? "出発" : "到着"
            annotation.coordinate = mapItem.placemark.coordinate
            mapView.addAnnotation(annotation)
        }
    }

    private func mapItem(for tollbooth: Tollbooth, completionHandler: @escaping (MKMapItem?) -> Void) {
        // TODO: This tends to pick wrong location
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "\(tollbooth.name)IC"

        MKLocalSearch(request: request).start { (response, error) in
            completionHandler(response?.mapItems.first)
        }
    }

    private func routeBetween(source: MKMapItem, destination: MKMapItem, completionHandler: @escaping (MKRoute?) -> Void) {
        let request = MKDirections.Request()
        request.source = source
        request.destination = destination
        request.transportType = .automobile

        MKDirections(request: request).calculate { (response, error) in
            completionHandler(response?.routes.first)
        }
    }

    private func clearMapView() {
        mapView.removeAnnotations(mapView.annotations)
        mapView.removeOverlays(mapView.overlays)
    }

    private var routeRectPadding: UIEdgeInsets {
        let horizontalPadding = mapView.bounds.width * 0.15
        let verticalPadding = mapView.bounds.height * 0.15

        return UIEdgeInsets(
            top: verticalPadding,
            left: horizontalPadding,
            bottom: verticalPadding,
            right: horizontalPadding
        )
    }

    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        guard !hasInitiallyZoomedToUserLocation else { return }

        let coordinateSpan = MKCoordinateSpan(latitudeDelta: 1, longitudeDelta: 1)
        let region = MKCoordinateRegion(center: userLocation.coordinate, span: coordinateSpan)
        mapView.region = region
        hasInitiallyZoomedToUserLocation = true
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard !(annotation is MKUserLocation) else { return nil }

        let view = mapView.dequeueReusableAnnotationView(withIdentifier: annotationViewIdentifier, for: annotation) as! MKMarkerAnnotationView
        view.titleVisibility = .visible
        view.subtitleVisibility = .visible
        return view
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let renderer = MKPolylineRenderer(polyline: overlay as! MKPolyline)
        renderer.lineWidth = 10
        renderer.strokeColor = UIColor(red: 73/255, green: 163/255, blue: 249/255, alpha: 1)
        return renderer
    }
}

