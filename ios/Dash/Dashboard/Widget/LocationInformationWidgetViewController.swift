//
//  LocationInformationWidgetViewController.swift
//  Dash
//
//  Created by Yuji Nakayama on 2021/06/15.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit
import CoreLocation

protocol LocationInformationWidgetViewControllerDelegate: NSObjectProtocol {
    func locationInformationWidget(_ viewController: LocationInformationWidgetViewController, didUpdateCurrentLocation location: CLLocation)
    func locationInformationWidget(_ viewController: LocationInformationWidgetViewController, didUpdateCurrentPlace place: OpenCage.Place, for location: CLLocation, reason: LocationInformationWidgetViewController.UpdateReason)
}

class LocationInformationWidgetViewController: UIViewController, CLLocationManagerDelegate {
    @IBOutlet weak var roadNameLabel: UILabel!
    @IBOutlet weak var canonicalRoadNameLabel: UILabel!
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var activityIndicatorView: UIActivityIndicatorView!

    weak var delegate: LocationInformationWidgetViewControllerDelegate?

    // https://opencagedata.com/pricing
    let maximumRequestCountPerDay = 2500

    // 34.56 seconds
    lazy var fixedUpdateInterval: TimeInterval = TimeInterval((60 * 60 * 24) / maximumRequestCountPerDay)

    let minimumMovementDistanceForIntervalUpdate: CLLocationDistance = 10

    lazy var locationManager: CLLocationManager = {
        let locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        return locationManager
    }()

    // horizontalAccuracy returns fixed value 65.0 in reinforced concrete buildings, which is unstable
    let requiredLocationAccuracy: CLLocationAccuracy = 65

    var isMetering = false

    lazy var openCage: OpenCage = {
        let path = Bundle.main.path(forResource: "opencage_api_key", ofType: "txt")!
        let apiKey = try! String(contentsOfFile: path)
        return OpenCage(apiKey: apiKey)
    }()

    var currentRequestTask: URLSessionTask?

    var currentPlace: OpenCage.Place? {
        didSet {
            currentRegion = currentPlace?.region.extended(by: Self.regionExtensionDistance)
        }
    }

    var currentRegion: OpenCage.Region?

    // We should extend original regions to avoid too frequent boundary detection caused by GPS errors
    // especially on roads running through north to south, or east to west, which tend to have very narrow region.
    static let regionExtensionDistance: CLLocationDistance = 5

    var lastRequestLocation: CLLocation?

    let vehicleMovement = VehicleMovement()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addInteraction(UIContextMenuInteraction(delegate: self))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if !isMetering {
            roadNameLabel.text = nil
            canonicalRoadNameLabel.text = nil
            addressLabel.text = nil
            hideLabelsWithNoContent()

            activityIndicatorView.startAnimating()

            startMetering()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        stopMetering()
        super.viewDidDisappear(animated)
    }

    func startMetering() {
        logger.info()

        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.startUpdatingLocation()
            isMetering = true
        default:
            locationManager.requestWhenInUseAuthorization()
        }
    }

    func stopMetering() {
        logger.info()

        locationManager.stopUpdatingLocation()
        isMetering = false

        currentRequestTask?.cancel()
        currentRequestTask = nil
        currentPlace = nil
        lastRequestLocation = nil
        vehicleMovement.reset()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        logger.info(manager.authorizationStatus.rawValue)

        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.startUpdatingLocation()
            isMetering = true
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        logger.debug()
        guard let location = locations.last else { return }
        delegate?.locationInformationWidget(self, didUpdateCurrentLocation: location)
        guard location.horizontalAccuracy < requiredLocationAccuracy else { return }
        updateIfNeeded(location: location)
    }

    func updateIfNeeded(location: CLLocation) {
        vehicleMovement.record(location)

        // Avoid parallel requests
        guard currentRequestTask == nil else { return }

        // If we have moved out from the region of the previous road, update.
        if let currentRegion = currentRegion, let lastRequestLocation = lastRequestLocation,
           currentRegion.contains(lastRequestLocation.coordinate), !currentRegion.contains(location.coordinate)
        {
            logger.debug("Request reason: Moved out from previous road region")
            performRequest(for: location, reason: .outOfRegion)
            return
        }

        // Even if we are still considered to be inside of the region of the current road,
        // update in a fixed interval because:
        // * The region is rectangular but actual road is not
        // * The current road may be wrong
        if let lastRequestLocation = lastRequestLocation {
            if location.timestamp >= lastRequestLocation.timestamp + fixedUpdateInterval,
               location.distance(from: lastRequestLocation) >= minimumMovementDistanceForIntervalUpdate
            {
                logger.debug("Request reason: Fixed time and distance have passed since previous request")
                performRequest(for: location, reason: .interval)
                return
            }
        } else {
            logger.debug("Request reason: Initial")
            performRequest(for: location, reason: .initial)
            return
        }

        // If we turned at an intersection, update
        if vehicleMovement.isEstimatedToHaveJustTurned {
            logger.debug("Request reason: Made a turn")
            vehicleMovement.reset()

            DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                self.performRequest(for: self.locationManager.location ?? location, reason: .turn)
            }

            return
        }
    }

    func performRequest(for location: CLLocation, reason: UpdateReason) {
        currentRequestTask = openCage.reverseGeocode(coordinate: location.coordinate) { (result) in
            logger.debug(result)

            switch result {
            case .success(let place):
                self.currentPlace = place
                self.lastRequestLocation = location

                DispatchQueue.main.async {
                    self.updateLabels(for: place)
                    self.delegate?.locationInformationWidget(self, didUpdateCurrentPlace: place, for: location, reason: reason)
                }
            case .failure(let error):
                logger.error(error)
            }

            self.currentRequestTask = nil
        }
    }

    func updateLabels(for place: OpenCage.Place) {
        activityIndicatorView.stopAnimating()
        updateRoadNameLabels(for: place)
        updateAddressLabel(for: place)
        hideLabelsWithNoContent()
    }

    func updateRoadNameLabels(for place: OpenCage.Place) {
        let roadName = RoadName(place: place)

        if let popularName = roadName.popularName {
            roadNameLabel.text = popularName
            canonicalRoadNameLabel.text = roadName.canonicalRoadName
        } else if let canonicalRoadName = roadName.canonicalRoadName {
            roadNameLabel.text = canonicalRoadName
            canonicalRoadNameLabel.text = nil
        } else if let unnumberedRouteName = roadName.unnumberedRouteName {
            roadNameLabel.text = unnumberedRouteName
            canonicalRoadNameLabel.text = nil
        } else {
            roadNameLabel.text = nil
            canonicalRoadNameLabel.text = nil
        }
    }

    func updateAddressLabel(for place: OpenCage.Place) {
        addressLabel.text = currentPlace?.address.components.joined(separator: " ")
    }

    func hideLabelsWithNoContent() {
        roadNameLabel.isHidden = roadNameLabel.text == nil
        canonicalRoadNameLabel.isHidden = canonicalRoadNameLabel.text == nil
        addressLabel.isHidden = addressLabel.text == nil
    }
}

extension LocationInformationWidgetViewController: UIContextMenuInteractionDelegate {
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        let actionProvider: UIContextMenuActionProvider = { (suggestedActions) in
            let action = UIAction(title: "Debug", image: UIImage(systemName: "ladybug")) { (action) in
                let debugViewContoller = LocationInformationDebugViewController()
                self.delegate = debugViewContoller

                let navigationController = UINavigationController(rootViewController: debugViewContoller)
                navigationController.modalPresentationStyle = .overCurrentContext
                self.present(navigationController, animated: true)
            }

            return UIMenu(title: "", children: [action])
        }

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil, actionProvider: actionProvider)
    }
}

extension LocationInformationWidgetViewController {
    class RoadName {
        let road: OpenCage.Road?
        let address: OpenCage.Address?

        init(place: OpenCage.Place) {
            road = place.road
            address = place.address
        }

        var popularName: String? {
            return popularNames.first
        }

        var popularNames: [String] {
            guard let road = road, let rawPopularName = road.popularName else { return [] }

            // Some roads have popular name properly containing multiple names (e.g. "目黒通り;東京都道312号白金台町等々力線")
            let rawPopularNames = rawPopularName.split(separator: ";").map { (name) in
                return String(name).covertFullwidthAlphanumericsToHalfwidth()
            }

            if let routeNumber = road.routeNumber {
                // Some roads have popular name only with route number (e.g. Popular name "123" for 国道123号),
                // which is redundant and meaningless.
                let redundantName = String(routeNumber)
                return rawPopularNames.filter { $0 != redundantName }
            } else {
                return rawPopularNames
            }
        }

        var canonicalRoadName: String? {
            guard let road = road else { return nil }

            if let roadIdentifier = road.identifier {
                return roadIdentifier
            }

            guard let routeNumber = road.routeNumber else { return nil }

            switch road.roadType {
            case .trunk:
                return "国道\(routeNumber)号"
            case .primary, .secondary:
                let prefecture = address?.prefecture ?? "都道府県"
                return "\(prefecture)道\(routeNumber)号"
            case .tertiary:
                let city = address?.city ?? "市町村"
                return "\(city)道\(routeNumber)号"
            default:
                return nil
            }
        }

        var unnumberedRouteName: String? {
            guard let road = road else { return nil }

            switch road.roadType {
            case .trunk:
                return "国道"
            case .primary, .secondary:
                let prefecture = address?.prefecture ?? "都道府県"
                return "\(prefecture)道"
            case .tertiary:
                let city = address?.city ?? "市町村"
                return "\(city)道"
            case .residential, .livingStreet:
                return "生活道路"
            case .track:
                return "農道・林道"
            default:
                return "一般道路"
            }
        }
    }
}

extension LocationInformationWidgetViewController {
    class VehicleMovement {
        private var locations: [CLLocation] = []

        let dropOutTimeInterval: TimeInterval = 5

        // 25km/h
        let maxTurnSpeed: CLLocationSpeed = 25 * (1000 / (60 * 60))

        let minTurnAngle: CLLocationDirection = 50

        func record(_ location: CLLocation) {
            locations.append(location)

            while let oldestLocation = locations.first, oldestLocation.timestamp.distance(to: location.timestamp) > dropOutTimeInterval {
                locations.removeFirst()
            }
        }

        func reset() {
            locations = []
        }

        var isEstimatedToHaveJustTurned: Bool {
            guard let averageSpeed = averageSpeed, let angleDelta = angleDelta else { return false }
            return averageSpeed <= maxTurnSpeed && angleDelta >= minTurnAngle
        }

        var averageSpeed: CLLocationSpeed? {
            guard !locations.isEmpty else { return nil }

            return locations.reduce(CLLocationSpeed(0)) { (averageSpeed, location) in
                averageSpeed + location.speed / Double(locations.count)
            }
        }

        var angleDelta: CLLocationDirection? {
            guard let firstLocation = locations.first, let lastLocation = locations.last else { return nil }
            return angleDelta(firstLocation.course, lastLocation.course)
        }

        private func angleDelta(_ a: CLLocationDirection, _ b: CLLocationDirection) -> CLLocationDirection {
            let delta = abs(b - a).truncatingRemainder(dividingBy: 360)
            return delta > 180 ? 360 - delta : delta
        }
    }
}

extension LocationInformationWidgetViewController {
    enum UpdateReason: String {
        case initial
        case interval
        case turn
        case outOfRegion
    }
}
