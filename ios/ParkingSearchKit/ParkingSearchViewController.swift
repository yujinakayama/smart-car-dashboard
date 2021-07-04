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

        return mapView
    }()

    lazy var searchManager = ParkingSearchMapViewManager(mapView: mapView)

    var optionsView: ParkingSearchOptionsView {
        return searchManager.optionsView
    }

    lazy var optionsSheetView: SheetView = {
        let sheetView = SheetView()

        sheetView.addSubview(optionsView)

        optionsView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            optionsView.leadingAnchor.constraint(equalTo: sheetView.layoutMarginsGuide.leadingAnchor),
            sheetView.layoutMarginsGuide.trailingAnchor.constraint(equalTo: optionsView.trailingAnchor),
            optionsView.topAnchor.constraint(equalTo: sheetView.layoutMarginsGuide.topAnchor),
            sheetView.layoutMarginsGuide.bottomAnchor.constraint(equalTo: optionsView.bottomAnchor),
        ])

        return sheetView
    }()

    let locationManager = CLLocationManager()

    public init(destination: MKMapItem) {
        self.destination = destination
        super.init(nibName: nil, bundle: nil)
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    open override func viewDidLoad() {
        super.viewDidLoad()

        searchManager.delegate = self

        locationManager.requestWhenInUseAuthorization()

        navigationItem.largeTitleDisplayMode = .never

        configureSubviews()

        if destination != nil {
            applyDestination()
        }
    }

    deinit {
        // > Before releasing an MKMapView object for which you have set a delegate,
        // > remember to set that object’s delegate property to nil.
        // https://developer.apple.com/documentation/mapkit/mkmapviewdelegate
        mapView.delegate = nil
    }

    func configureSubviews() {
        view.addSubview(mapView)

        view.subviews.forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        NSLayoutConstraint.activate([
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: mapView.trailingAnchor),
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            view.bottomAnchor.constraint(equalTo: mapView.bottomAnchor),
        ])

        changeSheetPlacementIfNeeded()
        view.addSubview(optionsSheetView)
    }

    private func changeSheetPlacementIfNeeded() {
        if traitCollection.horizontalSizeClass == .compact {
            optionsSheetView.placement = .bottomAttached
        } else {
            optionsSheetView.placement = .rightBottom
        }
    }

    func applyDestination() {
        if let locationName = destination.name {
            navigationItem.title = "”\(locationName)“ 周辺の駐車場"
        } else {
            navigationItem.title = "周辺の駐車場"
        }

        let region = MKCoordinateRegion(center: destination.placemark.coordinate, latitudinalMeters: 500, longitudinalMeters: 500)
        mapView.setRegion(region, animated: false)

        searchManager.setDestination(destination.placemark.coordinate)
    }

    open override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        changeSheetPlacementIfNeeded()
    }
}

extension ParkingSearchViewController: MKMapViewDelegate {
    open func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        guard let userLocationView = mapView.view(for: userLocation) as? DirectionalUserLocationAnnotationView else { return }
        userLocationView.updateDirection(animated: true)
    }

    open func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        switch annotation {
        case let userLocation as MKUserLocation:
            return viewForUserLocation(userLocation)
        default:
            return searchManager.view(for: annotation)
        }
    }

    private func viewForUserLocation(_ annotation: MKUserLocation) -> MKAnnotationView {
        return mapView.dequeueReusableAnnotationView(withIdentifier: "DirectionalUserLocationAnnotationView", for: annotation)
    }
}

extension ParkingSearchViewController: ParkingSearchMapViewManagerDelegate {
    public func parkingSearchMapViewManager(_ manager: ParkingSearchMapViewManager, didSelectParking parking: Parking, forReservationWebPage url: URL) {
        let webViewController = WebViewController(url: url)
        webViewController.navigationItem.title = parking.name

        let navigationController = UINavigationController(rootViewController: webViewController)
        navigationController.isToolbarHidden = false

        present(navigationController, animated: true)
    }
}
