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

class MapsViewController: UIViewController {
    static let directionalUserLocationAnnotationViewIdentifier = String(describing: DirectionalUserLocationAnnotationView.self)
    static let pointOfInterestAnnotationViewIdentifier = String(describing: PointOfInterestAnnotationView.self)

    lazy var mapView: MKMapView = {
        let mapView = MKMapView()
        mapView.delegate = self

        mapView.showsBuildings = true
        mapView.showsCompass = true
        mapView.showsScale = true
        mapView.showsTraffic = true
        mapView.showsUserLocation = true

        mapView.isPitchEnabled = false
        mapView.isRotateEnabled = false
        mapView.isScrollEnabled = true
        mapView.isZoomEnabled = true

        mapView.register(DirectionalUserLocationAnnotationView.self, forAnnotationViewWithReuseIdentifier: Self.directionalUserLocationAnnotationViewIdentifier)

        mapView.addGestureRecognizer(gestureRecognizer)

        mapView.addInteraction(UIDropInteraction(delegate: self))

        return mapView
    }()

    lazy var mapTypeSegmentedControl: MapTypeSegmentedControl = {
        let segmentedControl = MapTypeSegmentedControl(mapTypes: [.standard, .hybridFlyover])
        segmentedControl.selectedMapType = mapView.mapType
        segmentedControl.addTarget(self, action: #selector(mapTypeSegmentedControlDidChange), for: .valueChanged)
        return segmentedControl
    }()

    private var currentMode: Mode = .standard {
        didSet {
            applyCurrentMode()
        }
    }

    let locationManager = CLLocationManager()

    var hasInitiallyEnabledUserTrackingMode = false

    lazy var gestureRecognizer: UIGestureRecognizer = {
        let gestureRecognizer = UILongPressGestureRecognizer()
        gestureRecognizer.delegate = self
        gestureRecognizer.minimumPressDuration = 0.75
        gestureRecognizer.addTarget(self, action: #selector(gestureRecognizerDidRecognizeLongPress))
        return gestureRecognizer
    }()

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
        stackView.distribution = .fill
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
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        return button
    }()

    private var officialParkingSearch: OfficialParkingSearch? {
        didSet {
            changePlacementOfOfficialParkingSearchStatusViewIfNeeded()
        }
    }

    private lazy var officialParkingSearchStatusView: OfficialParkingSearchStatusView = {
        let view = OfficialParkingSearchStatusView()
        view.layer.cornerRadius = 8
        view.button.addTarget(self, action: #selector(officialParkingSearchStatusViewButtonDidPush), for: .touchUpInside)
        return view
    }()

    private lazy var statusBarUnderNavigationBar: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .center

        let visualEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))

        let bottomBorderView = UIView()
        bottomBorderView.backgroundColor = UIColor(named: "SystemChromeShadowColor")

        stackView.addSubview(visualEffectView)
        stackView.addSubview(bottomBorderView)

        stackView.subviews.forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        NSLayoutConstraint.activate([
            visualEffectView.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor),
            visualEffectView.topAnchor.constraint(equalTo: stackView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor),
        ])

        NSLayoutConstraint.activate([
            bottomBorderView.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: bottomBorderView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomBorderView.bottomAnchor),
            bottomBorderView.heightAnchor.constraint(equalToConstant: 1.0 / UIScreen.main.scale)
        ])

        return stackView
    }()

    private lazy var geocoder = CLGeocoder()

    var showsRecentSharedLocations = true {
        didSet {
            if showsRecentSharedLocations {
                updateSharedLocationAnnotations()
            } else {
                removeSharedLocationAnnotations()
            }
        }
    }

    private var sharedItemDatabaseObservation: NSKeyValueObservation?
    private var sharedItemQuerySubscription: FirestoreQuery<SharedItemProtocol>.CountSubscription?

    private var sharedLocationAnnotations: [MKAnnotation] = []

    var isVisible = false

    override func viewDidLoad() {
        super.viewDidLoad()

        // https://developer.apple.com/forums/thread/682420
        navigationItem.scrollEdgeAppearance = navigationController?.navigationBar.standardAppearance

        navigationItem.largeTitleDisplayMode = .never

        locationManager.requestWhenInUseAuthorization()

        configureSubviews()

        configureSharedItemDatabase()

        applyCurrentMode()

        NotificationCenter.default.addObserver(self, selector: #selector(locationTrackerDidStartTracking), name: .LocationTrackerDidStartTracking, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(locationTrackerDidStopTracking), name: .LocationTrackerDidStopTracking, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateTrackOverlay), name: .LocationTrackerDidUpdateCurrentTrack, object: nil)
    }

    deinit {
        // > Before releasing an MKMapView object for which you have set a delegate,
        // > remember to set that object’s delegate property to nil.
        // https://developer.apple.com/documentation/mapkit/mkmapviewdelegate
        mapView.delegate = nil
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        isVisible = true

        enableInitialUserTrackingModeIfNeeded()

        // This is to prevent ugly animation of user location annotation view
        // when switched back to Maps tab.
        mapView.showsUserLocation = true

        updateTrackOverlay()

        parkingSearchManager.viewWillAppear()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        isVisible = false

        // This is to prevent ugly animation of user location annotation view
        // when switched back to Maps tab.
        mapView.showsUserLocation = false

        parkingSearchManager.viewDidDissapear()
    }

    private func configureSubviews() {
        view.addSubview(mapView)
        view.addSubview(mapTypeSegmentedControl)
        view.addSubview(statusBarUnderNavigationBar)

        view.subviews.forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        NSLayoutConstraint.activate([
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: mapView.trailingAnchor),
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            view.bottomAnchor.constraint(equalTo: mapView.bottomAnchor),
        ])

        NSLayoutConstraint.activate([
            mapTypeSegmentedControl.leftAnchor.constraint(greaterThanOrEqualTo: view.layoutMarginsGuide.leftAnchor),
            view.layoutMarginsGuide.rightAnchor.constraint(equalTo: mapTypeSegmentedControl.rightAnchor),
            mapTypeSegmentedControl.topAnchor.constraint(equalTo: statusBarUnderNavigationBar.bottomAnchor, constant: 20),
            mapTypeSegmentedControl.widthAnchor.constraint(greaterThanOrEqualToConstant: 200),
        ])

        NSLayoutConstraint.activate([
            statusBarUnderNavigationBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: statusBarUnderNavigationBar.trailingAnchor),
            statusBarUnderNavigationBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
        ])

        changePlacementOfParkingSearchOptionsSheetViewIfNeeded()
        view.addSubview(parkingSearchOptionsSheetView)

        changePlacementOfOfficialParkingSearchStatusViewIfNeeded()
    }

    private func configureSharedItemDatabase() {
        sharedItemDatabaseObservation = Firebase.shared.observe(\.sharedItemDatabase, options: .initial) { [weak self] (firebase, change) in
            guard let self = self else { return }

            if let database = Firebase.shared.sharedItemDatabase {
                self.sharedItemQuerySubscription = database.items(type: .location).subscribeToCountUpdates { (result) in
                    self.updateSharedLocationAnnotations()
                }
            } else {
                self.sharedItemQuerySubscription = nil
                self.removeSharedLocationAnnotations()
            }
        }
    }

    private func changePlacementOfParkingSearchOptionsSheetViewIfNeeded() {
        if traitCollection.horizontalSizeClass == .compact {
            parkingSearchOptionsSheetView.placement = .bottomAttached
        } else {
            parkingSearchOptionsSheetView.placement = .rightBottom
        }
    }

    private func changePlacementOfOfficialParkingSearchStatusViewIfNeeded() {
        statusBarUnderNavigationBar.removeArrangedSubview(officialParkingSearchStatusView)
        statusBarUnderNavigationBar.isHidden = true
        navigationItem.rightBarButtonItem = nil
        officialParkingSearchStatusView.removeFromSuperview()

        if officialParkingSearch == nil { return }

        if traitCollection.horizontalSizeClass == .compact {
            officialParkingSearchStatusView.backgroundColor = nil
            statusBarUnderNavigationBar.addArrangedSubview(officialParkingSearchStatusView)
            statusBarUnderNavigationBar.isHidden = false
        } else {
            officialParkingSearchStatusView.backgroundColor = .tertiarySystemFill
            navigationItem.rightBarButtonItem = UIBarButtonItem(customView: officialParkingSearchStatusView)
        }
    }

    @objc func parkingSearchQuittingButtonDidPush() {
        currentMode = .standard
    }

    func enableInitialUserTrackingModeIfNeeded() {
        guard !hasInitiallyEnabledUserTrackingMode else { return }
        hasInitiallyEnabledUserTrackingMode = true
        guard currentMode == .standard else { return }

        DispatchQueue.main.async {
            self.mapView.setUserTrackingMode(.follow, animated: false)
        }
    }

    func applyCurrentMode() {
        switch currentMode {
        case .standard:
            navigationController?.setNavigationBarHidden(true, animated: true)
            parkingSearchOptionsSheetView.hide()
            parkingSearchManager.clearMapView()
            geocoder.cancelGeocode()
            officialParkingSearch = nil
        case .parkingSearch:
            parkingSearchOptionsSheetView.show()
        }

        updatePointOfInterestFilter()
    }

    @objc private func gestureRecognizerDidRecognizeLongPress() {
        guard gestureRecognizer.state == .began else { return }

        let longPressPoint = gestureRecognizer.location(in: mapView)
        let coordinate = mapView.convert(longPressPoint, toCoordinateFrom: mapView)

        startSearchingParkings(destination: coordinate)
    }

    @objc func mapTypeSegmentedControlDidChange() {
        mapView.mapType = mapTypeSegmentedControl.selectedMapType ?? .standard
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

    func startSearchingParkings(destination: MKMapItem) {
        guard let destinationName = destination.name else {
            startSearchingParkings(destination: destination.placemark.coordinate)
            return
        }

        currentMode = .parkingSearch

        parkingSearchManager.preferredMaxDistanceFromDestinationToParking = Defaults.shared.preferredMaxDistanceFromDestinationToParking
        parkingSearchManager.destination = destination.placemark.coordinate

        if let officialParkingSearch = try? OfficialParkingSearch(destination: destination, webView: WebViewController.makeWebView()) {
            officialParkingSearch.delegate = self
            officialParkingSearch.webView.customUserAgent = WebViewController.userAgent(for: .mobile)
            officialParkingSearch.start()

            officialParkingSearchStatusView.state = .searching

            self.officialParkingSearch = officialParkingSearch
        }

        navigationItem.title = String(localized: "Parkings Nearby “\(destinationName)”")
        navigationController?.setNavigationBarHidden(false, animated: isViewLoaded)
    }

    func startSearchingParkings(destination: CLLocationCoordinate2D) {
        currentMode = .parkingSearch

        parkingSearchManager.preferredMaxDistanceFromDestinationToParking = Defaults.shared.preferredMaxDistanceFromDestinationToParking
        parkingSearchManager.destination = destination

        officialParkingSearch = nil

        reverseGeocode(coordinate: destination) { (result) in
            guard self.currentMode == .parkingSearch else { return }

            switch result {
            case .success(let placemark):
                if let locationName = placemark.name {
                    self.navigationItem.title = String(localized: "Parkings Nearby “\(locationName)”")
                } else {
                    self.navigationItem.title = String(localized: "Parkings")
                }
            case .failure(let error):
                logger.error(error)
                self.navigationItem.title = String(localized: "Parkings")
            }

            self.navigationController?.setNavigationBarHidden(false, animated: self.isViewLoaded)
        }
    }

    private func reverseGeocode(coordinate: CLLocationCoordinate2D,completion: @escaping (Result<CLPlacemark, Error>) -> Void) {
        geocoder.cancelGeocode()

        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        geocoder.reverseGeocodeLocation(location) { (placemarks, error) in
            if let error = error {
                completion(.failure(error))
                return
            }

            if let placemark = placemarks?.first {
                completion(.success(placemark))
            }
        }
    }

    @objc private func officialParkingSearchStatusViewButtonDidPush() {
        guard let officialParkingSearch = officialParkingSearch else { return }

        let webViewController = OfficialParkingInformationWebViewController(officialParkingSearch: officialParkingSearch)

        let navigationController = UINavigationController(rootViewController: webViewController)
        navigationController.isToolbarHidden = false
        navigationController.modalPresentationStyle = .formSheet
        navigationController.preferredContentSize = UIScreen.main.bounds.size
        present(navigationController, animated: true)
    }

    private func updateSharedLocationAnnotations() {
        guard showsRecentSharedLocations else { return }

        removeSharedLocationAnnotations()

        Task {
            await addSharedLocationAnnotations()
        }
    }

    private func removeSharedLocationAnnotations() {
        mapView.removeAnnotations(sharedLocationAnnotations)
        sharedLocationAnnotations = []
    }

    private func addSharedLocationAnnotations() async {
        guard let database = Firebase.shared.sharedItemDatabase else { return }

        let threeDaysAgo = Date(timeIntervalSinceNow: -3 * 24 * 60 * 60)
        let query = database.items(type: .location, createdAfter: threeDaysAgo)

        guard let recentLocations = try? await query.get() as? [Location] else { return }

        sharedLocationAnnotations = recentLocations.map { (location) in
            return SharedLocationAnnotation(location)
        }

        await MainActor.run {
            mapView.addAnnotations(sharedLocationAnnotations)
        }
    }

    private func viewForSharedLocationAnnotation(_ annotation: SharedLocationAnnotation) -> MKAnnotationView {
        if let view = mapView.dequeueReusableAnnotationView(withIdentifier: Self.pointOfInterestAnnotationViewIdentifier) as? PointOfInterestAnnotationView {
            view.annotation = annotation
            return view
        } else {
            let view = PointOfInterestAnnotationView(annotation: annotation, reuseIdentifier: Self.pointOfInterestAnnotationViewIdentifier)
            view.callout.departureButton.addTarget(self, action: #selector(openDirectionsInMapsForSelectedSharedLocationAnnotation), for: .touchUpInside)
            view.callout.parkingSearchButton.addTarget(self, action: #selector(startSearchingParkingsForSelectedSharedLocationAnnotation), for: .touchUpInside)
            return view
        }
    }

    @objc func openDirectionsInMapsForSelectedSharedLocationAnnotation() {
        guard let location = (mapView.selectedAnnotations.first as? SharedLocationAnnotation)?.location else { return }
        location.markAsOpened(true)
        location.openDirectionsInMaps()
    }

    @objc func startSearchingParkingsForSelectedSharedLocationAnnotation() {
        guard let location = (mapView.selectedAnnotations.first as? SharedLocationAnnotation)?.location else { return }
        startSearchingParkings(destination: location.mapItem)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        changePlacementOfParkingSearchOptionsSheetViewIfNeeded()
        changePlacementOfOfficialParkingSearchStatusViewIfNeeded()
    }

    @objc func locationTrackerDidStartTracking() {
        // We remove previous track overlay when new tracking just started rather than when stopped
        // because users may want to view the track just after the previous arrival.
        if let trackOverlay = trackOverlay {
            mapView.removeOverlay(trackOverlay)
        }
    }

    @objc func locationTrackerDidStopTracking() {
        // If user don't want to show track on maps, remove it immediately.
        if !Defaults.shared.showTrackOnMaps, let trackOverlay = trackOverlay {
            mapView.removeOverlay(trackOverlay)
        }
    }

    @objc func updateTrackOverlay() {
        guard isVisible, let track = LocationTracker.shared.currentTrack else { return }

        let newOverlay = MKPolyline(coordinates: track.coordinates, count: track.coordinates.count)
        mapView.addOverlay(newOverlay)

        if let oldOverlay = trackOverlay {
            mapView.removeOverlay(oldOverlay)
        }

        trackOverlay = newOverlay
    }

    private var trackOverlay: MKOverlay?
}

extension MapsViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation {
            return mapView.dequeueReusableAnnotationView(withIdentifier: Self.directionalUserLocationAnnotationViewIdentifier, for: annotation)
        } else if let annotation = annotation as? SharedLocationAnnotation {
            return viewForSharedLocationAnnotation(annotation)
        } else if currentMode == .parkingSearch {
            return parkingSearchManager.view(for: annotation)
        } else {
            return nil
        }
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        switch overlay {
        case let polyline as MKPolyline:
            let renderer = GradientPathRenderer(
                polyline: polyline,
                colors: [UIColor(named: "Route Line Color")!],
                showsBorder: true,
                borderColor: UIColor(named: "Route Border Color")!
            )
            renderer.lineWidth = 8
            return renderer
        default:
            return MKOverlayRenderer(overlay: overlay)
        }
    }

    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        if let userLocationView = mapView.view(for: userLocation) as? DirectionalUserLocationAnnotationView {
            userLocationView.updateDirection(animated: true)
        }
    }
}

extension MapsViewController: ParkingSearchMapViewManagerDelegate {
    func parkingSearchMapViewManager(_ manager: ParkingSearchMapViewManager, didSelectParking parking: ParkingProtocol, forReservationWebPage url: URL) {
        presentWebViewController(url: url)
    }

    func parkingSearchMapViewManager(_ manager: ParkingSearchMapViewManager, didSelectParkingForSearchingOnWeb parking: ParkingProtocol) {
        var urlComponents = URLComponents(string: "https://google.com/search")!
        urlComponents.queryItems = [URLQueryItem(name: "q", value: "\(parking.normalizedName) 駐車場")]
        guard let url = urlComponents.url else { return }
        presentWebViewController(url: url)
    }

    private func presentWebViewController(url: URL) {
        let webViewController = WebViewController()
        webViewController.loadPage(url: url)

        let navigationController = UINavigationController(rootViewController: webViewController)
        navigationController.isToolbarHidden = false
        navigationController.modalPresentationStyle = .formSheet
        navigationController.preferredContentSize = UIScreen.main.bounds.size

        present(navigationController, animated: true)
    }
}

extension MapsViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        let point = touch.location(in: mapView)
        let touchedView = mapView.hitTest(point, with: nil)

        var ancestorView = touchedView

        while let view = ancestorView?.superview {
            // Disable long press gesture in callout views
            if String(describing: type(of: view)) == "MKStandardCalloutView" {
                return false
            }

            ancestorView = view
        }

        return true
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
                self.startSearchingParkings(destination: mapItem)
            }
        }
    }
}

extension MapsViewController: OfficialParkingSearchDelegate {
    func officialParkingSearch(_ officialParkingSearch: OfficialParkingSearch, didChange state: OfficialParkingSearch.State) {
        officialParkingSearchStatusView.parkingInformation = officialParkingSearch.parkingInformation
        officialParkingSearchStatusView.state = state
    }
}

extension MapsViewController {
    enum Mode: Int {
        case standard
        case parkingSearch
    }
}

extension MapsViewController: TabReselectionRespondable {
    func tabBarControllerDidReselectAlreadyVisibleTab(_ tabBarController: UITabBarController) {
        mapView.setUserTrackingMode(.follow, animated: true)
    }
}
