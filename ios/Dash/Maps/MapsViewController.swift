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
import FloatingPanel

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

        mapView.isPitchEnabled = true
        mapView.isRotateEnabled = false
        mapView.isScrollEnabled = true
        mapView.isZoomEnabled = true

        mapView.selectableMapFeatures = [.pointsOfInterest, .physicalFeatures]

        mapView.register(DirectionalUserLocationAnnotationView.self, forAnnotationViewWithReuseIdentifier: Self.directionalUserLocationAnnotationViewIdentifier)
        mapView.register(PointOfInterestAnnotationView.self, forAnnotationViewWithReuseIdentifier: Self.pointOfInterestAnnotationViewIdentifier)

        mapView.addGestureRecognizer(gestureRecognizer)

        mapView.addInteraction(UIDropInteraction(delegate: self))

        return mapView
    }()

    var focusedLocation: Location? {
        didSet {
            let annotations = mapView.annotations.filter { $0 is FocusedLocationAnnotation }
            mapView.removeAnnotations(annotations)

            if let location = focusedLocation {
                navigationItem.title = location.name
                mapView.addAnnotation(FocusedLocationAnnotation(location))
                setRegion(for: location, animated: true)
            } else {
                navigationItem.title = nil
            }

            applyCurrentMode()
        }
    }

    lazy var configuratorSegmentedControl: MapConfiguratorSegmentedControl = {
        let segmentedControl = MapConfiguratorSegmentedControl(configurators: [.standard, .satellite])
        segmentedControl.selectedConfigurator = .standard
        segmentedControl.addTarget(self, action: #selector(applySelectedConfigurator), for: .valueChanged)
        return segmentedControl
    }()

    private var currentMode: Mode = .standard {
        didSet {
            applyCurrentMode()
        }
    }

    let locationManager = {
        let locationManager = CLLocationManager()
        locationManager.pausesLocationUpdatesAutomatically = false
        return locationManager
    }()

    var hasInitiallyEnabledUserTrackingMode = false

    lazy var pointOfInterestViewController = PointOfInterestViewController(delegate: self, searchParkingsHandler: { [weak self] (location) in
        self?.startSearchingParkings(destination: location.mapItem)
    })
    
    lazy var pointOfInterestFloatingController: FloatingPanelController = {
        let controller = FloatingPanelController()
        controller.delegate = self

        // To avoid perfomance degradation of map view scrolling,
        // hide backdrop view since we don't use the features
        // such as tapping backdrop to hide surface view.
        controller.view.backgroundColor = nil
        controller.backdropView.isHidden = true
        
        let visualEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThickMaterial))
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        let surfaceContainerView = controller.surfaceView.containerView
        surfaceContainerView.addSubview(visualEffectView)
        NSLayoutConstraint.activate([
            visualEffectView.leftAnchor.constraint(equalTo: surfaceContainerView.leftAnchor),
            visualEffectView.rightAnchor.constraint(equalTo: surfaceContainerView.rightAnchor),
            visualEffectView.topAnchor.constraint(equalTo: surfaceContainerView.topAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: surfaceContainerView.bottomAnchor),
        ])
        
        controller.surfaceView.appearance = {
            let appearance = SurfaceAppearance()
            appearance.cornerCurve = .continuous
            appearance.cornerRadius = 10
            appearance.backgroundColor = nil
            return appearance
        }()

        controller.layout = PointOfInterestPanelLayout()
        
        controller.surfaceView.grabberHandle.barColor = .systemGray2
        controller.surfaceView.contentPadding = .init(top: 16, left: 16, bottom: 16, right: 16)

        controller.set(contentViewController: pointOfInterestViewController)
        controller.addPanel(toParent: self)

        pointOfInterestViewController.registerForTraitChanges([UITraitHorizontalSizeClass.self]) { (_: PointOfInterestViewController, _) in
            controller.invalidateLayout()
        }

        return controller
    }()

    private var pointOfInterestViewHidingTimer: Timer?

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
                Task {
                    await updateSharedLocationAnnotations()
                }
            } else {
                removeSharedLocationAnnotations()
            }
        }
    }

    private var inboxItemDatabaseObservation: NSKeyValueObservation?
    private var inboxItemQuerySubscription: FirestoreQuery<InboxItemProtocol>.CountSubscription?

    var isVisible = false

    override func viewDidLoad() {
        super.viewDidLoad()

        // https://developer.apple.com/forums/thread/682420
        navigationItem.scrollEdgeAppearance = navigationController?.navigationBar.standardAppearance

        navigationItem.largeTitleDisplayMode = .never

        locationManager.requestWhenInUseAuthorization()

        configureSubviews()

        configureInboxItemDatabase()

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
        view.addSubview(configuratorSegmentedControl)
        view.addSubview(statusBarUnderNavigationBar)

        view.subviews.forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        NSLayoutConstraint.activate([
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: mapView.trailingAnchor),
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            view.bottomAnchor.constraint(equalTo: mapView.bottomAnchor),
        ])

        NSLayoutConstraint.activate([
            configuratorSegmentedControl.leftAnchor.constraint(greaterThanOrEqualTo: view.layoutMarginsGuide.leftAnchor),
            view.layoutMarginsGuide.rightAnchor.constraint(equalTo: configuratorSegmentedControl.rightAnchor),
            configuratorSegmentedControl.topAnchor.constraint(equalTo: statusBarUnderNavigationBar.bottomAnchor, constant: 20),
            configuratorSegmentedControl.widthAnchor.constraint(greaterThanOrEqualToConstant: 200),
        ])

        NSLayoutConstraint.activate([
            statusBarUnderNavigationBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: statusBarUnderNavigationBar.trailingAnchor),
            statusBarUnderNavigationBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
        ])

        applySelectedConfigurator()
        
        _ = pointOfInterestFloatingController
        
        changePlacementOfParkingSearchOptionsSheetViewIfNeeded()
        view.addSubview(parkingSearchOptionsSheetView)

        changePlacementOfOfficialParkingSearchStatusViewIfNeeded()
    }

    private func configureInboxItemDatabase() {
        if showsRecentSharedLocations {
            inboxItemDatabaseObservation = Firebase.shared.observe(\.inboxItemDatabase, options: .initial) { [weak self] (firebase, change) in
                guard let self = self else { return }

                if let database = Firebase.shared.inboxItemDatabase {
                    self.inboxItemQuerySubscription = database.items(type: .location).subscribeToCountUpdates { (result) in
                        Task {
                            await self.updateSharedLocationAnnotations()
                        }
                    }
                } else {
                    self.inboxItemQuerySubscription = nil
                    self.removeSharedLocationAnnotations()
                }
            }
        } else {
            inboxItemDatabaseObservation?.invalidate()
            inboxItemDatabaseObservation = nil
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

        DispatchQueue.main.async {
            if self.traitCollection.horizontalSizeClass == .compact {
                self.officialParkingSearchStatusView.backgroundColor = nil
                self.statusBarUnderNavigationBar.addArrangedSubview(self.officialParkingSearchStatusView)
                self.statusBarUnderNavigationBar.isHidden = false
            } else {
                self.officialParkingSearchStatusView.backgroundColor = .tertiarySystemFill
                self.navigationItem.rightBarButtonItem = UIBarButtonItem(customView: self.officialParkingSearchStatusView)
            }
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
            navigationController?.setNavigationBarHidden(focusedLocation == nil, animated: true)
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

    @objc func applySelectedConfigurator() {
        configuratorSegmentedControl.selectedConfigurator?.configure(mapView)
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
        switch mapView.preferredConfiguration {
        case is MKStandardMapConfiguration:
            return nil
        case is MKHybridMapConfiguration:
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

    private func setRegion(for location: Location, animated: Bool) {
        let region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: 1000,
            longitudinalMeters: 1000
        )

        if isViewLoaded {
            mapView.setRegion(region, animated: animated)
        } else {
            pendingRegion = region
        }
    }

    private var pendingRegion: MKCoordinateRegion?

    func startSearchingParkings(destination: MKMapItem) {
        guard let destinationName = destination.name else {
            startSearchingParkings(destination: destination.placemark.coordinate)
            return
        }

        currentMode = .parkingSearch

        parkingSearchManager.preferredMaxDistanceFromDestinationToParking = Defaults.shared.preferredMaxDistanceFromDestinationToParking
        parkingSearchManager.destination = destination.placemark.coordinate

        if let officialParkingSearch = try? OfficialParkingSearch(destination: destination, webViewConfiguration: WebViewController.webViewConfiguration) {
            officialParkingSearch.delegate = self
            officialParkingSearch.webView.customUserAgent = WebViewController.userAgent(for: .mobile)
            officialParkingSearch.start()
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

    private func removeSharedLocationAnnotations() {
        let annotations = mapView.annotations.filter { $0 is InboxLocationAnnotation }
        mapView.removeAnnotations(annotations)
    }

    private func updateSharedLocationAnnotations() async {
        guard let recentLocations = await recentLocations() else { return }

        let existingAnnotations = mapView.annotations.filter { $0 is InboxLocationAnnotation } as! [InboxLocationAnnotation]
        let existingLocations = Set(existingAnnotations.map { $0.inboxLocation })

        let locationsToAdd = recentLocations.subtracting(existingLocations)
        let annotationsToAdd = locationsToAdd.map { (location) in
            return InboxLocationAnnotation(location)
        }

        let locationsToRemove = existingLocations.subtracting(recentLocations)
        let annotationsToRemove = locationsToRemove.compactMap { (location) in
            return existingAnnotations.first { $0.inboxLocation == location }
        }

        await MainActor.run {
            mapView.removeAnnotations(annotationsToRemove)
            mapView.addAnnotations(annotationsToAdd)
        }
    }

    private func recentLocations() async -> Set<InboxLocation>? {
        guard let database = Firebase.shared.inboxItemDatabase else { return nil }

        let oneWeekAgo = Date(timeIntervalSinceNow: -7 * 24 * 60 * 60)
        let query = database.items(type: .location, createdAfter: oneWeekAgo)

        guard let locations = try? await query.get() as? [InboxLocation] else {
            return nil
        }

        return Set(locations)
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
    func mapViewWillStartLoadingMap(_ mapView: MKMapView) {
        if let pendingRegion = pendingRegion {
            mapView.region = pendingRegion
            self.pendingRegion = nil
        }
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation {
            return mapView.dequeueReusableAnnotationView(withIdentifier: Self.directionalUserLocationAnnotationViewIdentifier, for: annotation)
        } else if let annotation = annotation as? PointOfInterestAnnotation {
            return mapView.dequeueReusableAnnotationView(withIdentifier: Self.pointOfInterestAnnotationViewIdentifier, for: annotation)
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
    
    func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {
        guard let pointOfInterestAnnotation = annotation as? PointOfInterestAnnotation else { return }

        pointOfInterestViewHidingTimer?.invalidate()
        pointOfInterestViewHidingTimer = nil

        pointOfInterestViewController.annotation = pointOfInterestAnnotation
        pointOfInterestFloatingController.move(to: .full, animated: true)
    }

    func mapView(_ mapView: MKMapView, didDeselect actuallyOptionalAnnotation: MKAnnotation) {
        // For some reason nil annotation may be given
        let optionalAnnotation: MKAnnotation? = actuallyOptionalAnnotation
        guard let annotation = optionalAnnotation else { return }

        if annotation === pointOfInterestViewController.annotation {
            // When user selected another annotation,
            // mapView(didDeselect:) is called first before mapView(didSelect:).
            // In such case we don't want to hide the floating panel
            // so we defer the hiding operation so that it can be canceled in mapView(didSelect:),
            // Without this handling, animation may move strangely.
            pointOfInterestViewHidingTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: false, block: { [weak self] timer in
                self?.pointOfInterestFloatingController.move(to: .hidden, animated: true)
            })
        }
    }
}

extension MapsViewController: FloatingPanelControllerDelegate {
    func floatingPanelDidChangeState(_ floatingPanelController: FloatingPanelController) {
        // Deselect annotation if floating panel is dismissed by swiping down
        if floatingPanelController.state == .hidden,
           let selectedAnnotation = mapView.selectedAnnotations.first,
           pointOfInterestViewController.annotation === selectedAnnotation
        {
            mapView.deselectAnnotation(selectedAnnotation, animated: true)
        }
    }
}

extension MapsViewController: PointOfInterestViewControllerDelegate {
    func pointOfInterestViewController(_ viewController: PointOfInterestViewController, didFetchFullLocation fullLocation: FullLocation, fromPartialLocation partialLocation: PartialLocation) {
        // If partial location and full location have different title,
        // height of title label may be changed.
        if fullLocation.name != partialLocation.name {
            pointOfInterestFloatingController.move(to: .full, animated: true)
        }
    }
}

extension MapsViewController: ParkingSearchMapViewManagerDelegate {
    func parkingSearchMapViewManager(_ manager: ParkingSearchMapViewManager, didSelectParking parking: ParkingProtocol, forReservationWebPage url: URL) {
        WebViewController.present(url: url, from: self)
    }

    func parkingSearchMapViewManager(_ manager: ParkingSearchMapViewManager, didSelectParkingForSearchingOnWeb parking: ParkingProtocol) {
        var queryWords = [parking.normalizedName]

        if !parking.normalizedName.contains("駐車場") {
            queryWords.append("駐車場")
        }

        queryWords.append(contentsOf: [
            parking.mapItem.placemark.administrativeArea,
            parking.mapItem.placemark.locality,
        ].compactMap { $0 })

        var urlComponents = URLComponents(string: "https://google.com/search")!
        urlComponents.queryItems = [URLQueryItem(name: "q", value: queryWords.joined(separator: " "))]

        guard let url = urlComponents.url else { return }
        WebViewController.present(url: url, from: self)
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

class PointOfInterestPanelLayout: FloatingPanelLayout {
    var position: FloatingPanelPosition {
        .bottom
    }

    var initialState: FloatingPanelState {
        .hidden
    }

    var anchors: [FloatingPanelState: FloatingPanelLayoutAnchoring] {
        return [
            .full: FloatingPanelIntrinsicLayoutAnchor(fractionalOffset: 0, referenceGuide: .safeArea),
            .hidden: FloatingPanelLayoutAnchor(fractionalInset: 0, edge: .bottom, referenceGuide: .superview)
        ]
    }

    func prepareLayout(surfaceView: UIView, in view: UIView) -> [NSLayoutConstraint] {
        if view.traitCollection.horizontalSizeClass == .compact {
            return [
                surfaceView.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor),
                view.safeAreaLayoutGuide.rightAnchor.constraint(equalTo: surfaceView.rightAnchor)
            ]
        } else {
            return [
                // Same as compact width size class
                surfaceView.widthAnchor.constraint(equalToConstant: 375),
                view.safeAreaLayoutGuide.rightAnchor.constraint(equalTo: surfaceView.rightAnchor, constant: 10)
            ]
        }
    }

    func backdropAlpha(for state: FloatingPanelState) -> CGFloat {
        return 0
    }
}
