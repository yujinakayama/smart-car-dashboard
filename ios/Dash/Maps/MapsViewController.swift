//
//  MapsViewController.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/04/05.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit
import MapKit
import DirectionalUserLocationAnnotationView
import ParkingSearchKit

class MapsViewController: UIViewController, MKMapViewDelegate, UIGestureRecognizerDelegate {
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var mapTypeSegmentedControl: UISegmentedControl!

    var parkingSearchDestination: CLLocationCoordinate2D? {
        didSet {
            if let parkingSearchDestination = parkingSearchDestination {
                parkingSearchManager.setDestination(parkingSearchDestination)
            }

            applyCurrentMode()
        }
    }

    private var currentMode: Mode {
        if parkingSearchDestination == nil {
            return .standard
        } else {
            return .parkingSearch
        }
    }

    let locationManager = CLLocationManager()

    lazy var gestureRecognizer: UIGestureRecognizer = {
        let gestureRecognizer = UILongPressGestureRecognizer()
        gestureRecognizer.delegate = self
        gestureRecognizer.minimumPressDuration = 0.75
        gestureRecognizer.addTarget(self, action: #selector(gestureRecognizerDidRecognizeLongPress))
        return gestureRecognizer
    }()

    let userTrackingModeRestorationInterval: TimeInterval = 10
    var userTrackingModeRestorationTimer: Timer?

    lazy var parkingSearchManager: ParkingSearchMapViewManager = {
        let parkingSearchManager = ParkingSearchMapViewManager(mapView: mapView)
        parkingSearchManager.delegate = self
        return parkingSearchManager
    }()

    lazy var parkingSearchOptionsSheetView: SheetView = {
        let stackView = UIStackView(arrangedSubviews: [
            parkingSearchManager.optionsView,
            parkingSearchQuittingButton,
        ])

        stackView.axis = .horizontal
        stackView.alignment = .fill
        stackView.distribution = .equalSpacing
        stackView.spacing = 8

        let sheetView = SheetView()
        sheetView.isHidden = true

        sheetView.addSubview(stackView)

        stackView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: sheetView.layoutMarginsGuide.leadingAnchor),
            sheetView.layoutMarginsGuide.trailingAnchor.constraint(equalTo: stackView.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: sheetView.layoutMarginsGuide.topAnchor),
            sheetView.layoutMarginsGuide.bottomAnchor.constraint(equalTo: stackView.bottomAnchor),
        ])

        return sheetView
    }()

    lazy var parkingSearchQuittingButton: UIButton = {
        let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: 28, weight: .semibold)
        let image = UIImage(systemName: "xmark.circle.fill", withConfiguration: symbolConfiguration)

        let button = UIButton()
        button.setImage(image, for: .normal)
        button.tintColor = .tertiaryLabel
        button.addTarget(self, action: #selector(parkingSearchQuittingButtonDidPush), for: .touchUpInside)
        button.setContentHuggingPriority(.required, for: .horizontal)
        return button
    }()

    private var sharedItemDatabaseObservation: NSKeyValueObservation?

    private var sharedLocationAnnotations: [MKAnnotation] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        locationManager.requestWhenInUseAuthorization()

        mapView.delegate = self
        mapView.register(DirectionalUserLocationAnnotationView.self, forAnnotationViewWithReuseIdentifier: "DirectionalUserLocationAnnotationView")
        mapView.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: "MKMarkerAnnotationView")
        mapView.setUserTrackingMode(.follow, animated: false)

        mapView.addGestureRecognizer(gestureRecognizer)

        mapView.addInteraction(UIDropInteraction(delegate: self))

        changeSheetPlacementIfNeeded()
        view.addSubview(parkingSearchOptionsSheetView)

        sharedItemDatabaseObservation = Firebase.shared.observe(\.sharedItemDatabase, options: .initial) { [weak self] (firebase, change) in
            self?.sharedItemDatabaseDidChange()
        }

        NotificationCenter.default.addObserver(self, selector: #selector(sharedItemDatabaseDidUpdateItems), name: .SharedItemDatabaseDidUpdateItems, object: nil)

        applyCurrentMode()
    }

    deinit {
        // > Before releasing an MKMapView object for which you have set a delegate,
        // > remember to set that object’s delegate property to nil.
        // https://developer.apple.com/documentation/mapkit/mkmapviewdelegate
        mapView.delegate = nil
    }

    private func changeSheetPlacementIfNeeded() {
        if traitCollection.horizontalSizeClass == .compact {
            parkingSearchOptionsSheetView.placement = .bottomAttached
        } else {
            parkingSearchOptionsSheetView.placement = .rightBottom
        }
    }

    @objc func parkingSearchQuittingButtonDidPush() {
        parkingSearchDestination = nil
    }

    func applyCurrentMode() {
        switch currentMode {
        case .standard:
            parkingSearchOptionsSheetView.hide()

            parkingSearchManager.clearMapView()

            if mapView.userTrackingMode != .follow {
                mapView.setUserTrackingMode(.follow, animated: true)
            }
        case .parkingSearch:
            parkingSearchOptionsSheetView.show()
            userTrackingModeRestorationTimer?.invalidate()
        }

        updatePointOfInterestFilter()
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        mapViewDidTouch()
        return true
    }

    private func mapViewDidTouch() {
        guard currentMode == .standard else { return }

        userTrackingModeRestorationTimer?.invalidate()

        userTrackingModeRestorationTimer = Timer.scheduledTimer(withTimeInterval: userTrackingModeRestorationInterval, repeats: false) { [weak self] (timer) in
            guard let self = self else { return }
            if self.mapView.userTrackingMode == .follow { return }
            self.mapView.setUserTrackingMode(.follow, animated: true)
            self.userTrackingModeRestorationTimer = nil
        }
    }

    @objc private func gestureRecognizerDidRecognizeLongPress() {
        guard gestureRecognizer.state == .began else { return }

        let longPressPoint = gestureRecognizer.location(in: mapView)
        let coordinate = mapView.convert(longPressPoint, toCoordinateFrom: mapView)
        parkingSearchDestination = coordinate
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation {
            return mapView.dequeueReusableAnnotationView(withIdentifier: "DirectionalUserLocationAnnotationView", for: annotation)
        } else if annotation is SharedLocationAnnotation {
            return mapView.dequeueReusableAnnotationView(withIdentifier: "MKMarkerAnnotationView", for: annotation)
        } else if currentMode == .parkingSearch {
            return parkingSearchManager.view(for: annotation)
        } else {
            return nil
        }
    }

    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        guard let userLocationView = mapView.view(for: userLocation) as? DirectionalUserLocationAnnotationView else { return }
        userLocationView.updateDirection(animated: true)
    }

    @IBAction func mapTypeSegmentedControlDidChange() {
        let index = MapTypeSegmentedControlIndex(rawValue: mapTypeSegmentedControl.selectedSegmentIndex)!
        mapView.mapType = index.mapType
        updatePointOfInterestFilter()
    }

    func updatePointOfInterestFilter() {
        mapView.pointOfInterestFilter = pointOfInterestFilterForCurrentMode
    }

    var pointOfInterestFilterForCurrentMode: MKPointOfInterestFilter? {
        switch currentMode {
        case .standard:
            return pointOfInterestFilterForStandardMode
        case .parkingSearch:
            return pointOfInterestFilterForParkingSearchMode
        }
    }

    // TODO: Make customizable on UI
    var pointOfInterestFilterForStandardMode: MKPointOfInterestFilter? {
        switch mapView.mapType {
        case .standard:
            return nil
        case .hybrid:
            return MKPointOfInterestFilter(including: [
                .airport,
                .amusementPark,
                .aquarium,
                .beach,
                .brewery,
                .campground,
                .hotel,
                .library,
                .marina,
                .movieTheater,
                .museum,
                .nationalPark,
                .park,
                .publicTransport,
                .stadium,
                .theater,
                .winery,
                .zoo
            ])
        default:
            return nil
        }
    }

    var pointOfInterestFilterForParkingSearchMode: MKPointOfInterestFilter {
        return MKPointOfInterestFilter(including: [.parking, .publicTransport])
    }

    func sharedItemDatabaseDidChange() {
        removeSharedLocationAnnotations()
    }

    @objc func sharedItemDatabaseDidUpdateItems(notification: Notification) {
        removeSharedLocationAnnotations()

        guard let database = Firebase.shared.sharedItemDatabase else { return }

        let threeDaysAgo = Date(timeIntervalSinceNow: -3 * 24 * 60 * 60)

        let recentLocations = database.items.filter { (item) in
            guard item is Location else { return false }
            guard let creationDate = item.creationDate else { return false }
            return creationDate >= threeDaysAgo
        } as! [Location]

        sharedLocationAnnotations = recentLocations.map { (location) in
            let annotation = SharedLocationAnnotation()
            annotation.title = location.title
            annotation.coordinate = location.coordinate
            return annotation
        }

        mapView.addAnnotations(sharedLocationAnnotations)
    }

    func removeSharedLocationAnnotations() {
        mapView.removeAnnotations(sharedLocationAnnotations)
        sharedLocationAnnotations = []
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        changeSheetPlacementIfNeeded()
    }
}

extension MapsViewController: ParkingSearchMapViewManagerDelegate {
    func parkingSearchMapViewManager(_ manager: ParkingSearchMapViewManager, didSelectParking parking: Parking, forReservationWebPage url: URL) {
        let webViewController = WebViewController(url: url)
        webViewController.navigationItem.title = parking.name

        let navigationController = UINavigationController(rootViewController: webViewController)
        navigationController.isToolbarHidden = false

        present(navigationController, animated: true)
    }
}

extension MapsViewController: UIDropInteractionDelegate {
    func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
        return session.canLoadObjects(ofClass: MKMapItem.self)
    }

    func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
        return .init(operation: .copy)
    }

    func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
        session.loadObjects(ofClass: MKMapItem.self) { (mapItems) in
            if let mapItem = mapItems.first as? MKMapItem {
                self.parkingSearchDestination = mapItem.placemark.coordinate
            }
        }
    }
}

extension MapsViewController {
    enum Mode: Int {
        case standard
        case parkingSearch
    }
}

extension MapsViewController {
    enum RestorationCodingKeys: String {
        case mapType
    }

    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        guard let mapView = mapView else { return } // For some reason mapView might be nil
        coder.encode(Int(mapView.mapType.rawValue), forKey: RestorationCodingKeys.mapType.rawValue)
    }

    override func decodeRestorableState(with coder: NSCoder) {
        if coder.containsValue(forKey: RestorationCodingKeys.mapType.rawValue),
           let mapType = MKMapType(rawValue: UInt(coder.decodeInteger(forKey: RestorationCodingKeys.mapType.rawValue))),
           let index = MapTypeSegmentedControlIndex(mapType)
        {
            mapTypeSegmentedControl.selectedSegmentIndex = index.rawValue
            mapTypeSegmentedControlDidChange()
        }

        super.decodeRestorableState(with: coder)
    }
}

extension MapsViewController: TabReselectionRespondable {
    func tabBarControllerDidReselectAlreadyVisibleTab(_ tabBarController: UITabBarController) {
        mapView.setUserTrackingMode(.follow, animated: true)
    }
}

fileprivate class SharedLocationAnnotation: MKPointAnnotation {
}
