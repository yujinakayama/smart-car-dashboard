//
//  LocationInformationWidgetViewController.swift
//  Dash
//
//  Created by Yuji Nakayama on 2021/06/15.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit
import CoreLocation

class LocationInformationWidgetViewController: UIViewController, CLLocationManagerDelegate {
    @IBOutlet weak var roadNameLabel: UILabel!
    @IBOutlet weak var canonicalRoadNameView: UIView!
    @IBOutlet weak var canonicalRoadNameLabel: UILabel!
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var activityIndicatorView: UIActivityIndicatorView!

    // https://opencagedata.com/pricing
    let maximumRequestCountPerDay = 2500

    // 34.56 seconds
    lazy var minimumRequestInterval: TimeInterval = TimeInterval((60 * 60 * 24) / maximumRequestCountPerDay)

    let minimumMovementDistanceForNextUpdate: CLLocationDistance = 10

    lazy var locationManager: CLLocationManager = {
        let locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        return locationManager
    }()

    var isMetering = false

    lazy var openCageClient: OpenCageClient = {
        let path = Bundle.main.path(forResource: "opencage_api_key", ofType: "txt")!
        let apiKey = try! String(contentsOfFile: path)
        return OpenCageClient(apiKey: apiKey)
    }()

    var lastRequestLocation: CLLocation?

    let vehicleMovement = VehicleMovement()

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if !isMetering {
            roadNameLabel.text = nil
            roadNameLabel.isHidden = true
            canonicalRoadNameLabel.text = nil
            canonicalRoadNameView.isHidden = true
            addressLabel.text = nil
            addressLabel.isHidden = true

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
        logger.info()
        guard let location = locations.last else { return }
        updateIfNeeded(location: location)
    }

    func updateIfNeeded(location: CLLocation) {
        vehicleMovement.record(location)

        if let lastRequestLocation = lastRequestLocation {
            if location.timestamp >= lastRequestLocation.timestamp + minimumRequestInterval,
               location.distance(from: lastRequestLocation) >= minimumMovementDistanceForNextUpdate
            {
                performRequest(for: location)
                return
            }
        } else {
            performRequest(for: location)
            return
        }

        if vehicleMovement.isEstimatedToHaveJustTurned {
            logger.info("VehicleMovement.isEstimatedToHaveJustTurned")
            vehicleMovement.reset()

            DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                self.performRequest(for: self.locationManager.location ?? location)
            }

            return
        }
    }

    func performRequest(for location: CLLocation) {
        openCageClient.reverseGeocode(coordinate: location.coordinate) { (result) in
            logger.debug(result)

            switch result {
            case .success(let location):
                DispatchQueue.main.async {
                    self.updateLabels(for: location)
                }
            case .failure(let error):
                logger.error(error)
            }
        }

        lastRequestLocation = location
    }

    func updateLabels(for location: OpenCageClient.Location) {
        activityIndicatorView.stopAnimating()
        updateRoadNameLabels(for: location)
        updateAddressLabel(for: location)
    }

    func updateRoadNameLabels(for location: OpenCageClient.Location) {
        let roadName = RoadName(location: location)

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

        roadNameLabel.isHidden = roadNameLabel.text == nil
        canonicalRoadNameView.isHidden = canonicalRoadNameLabel.text == nil
    }

    func updateAddressLabel(for location: OpenCageClient.Location) {
        if let address = location.address {
            addressLabel.text = format(address)
        } else {
            addressLabel.text = nil
        }

        addressLabel.isHidden = addressLabel.text == nil
    }

    func format(_ address: OpenCageClient.Address) -> String {
        return [address.prefecture, address.city, address.suburb, address.neighbourhood].compactMap { $0 }.joined(separator: " ")
    }
}

extension LocationInformationWidgetViewController {
    class RoadName {
        let road: OpenCageClient.Road?
        let address: OpenCageClient.Address?

        init(location: OpenCageClient.Location) {
            road = location.road
            address = location.address
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
            logger.debug("averageSpeed: \(String(format: "%.0f", averageSpeed / 1000 * 60 * 60))km/h, angleDelta: \(String(format: "%.0f", angleDelta))")
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
