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

    // https://opencagedata.com/pricing
    let maximumRequestCountPerDay = 2500

    // 34.56 seconds
    lazy var minimumRequestInterval: TimeInterval = TimeInterval((60 * 60 * 24) / maximumRequestCountPerDay)

    let minimumMovementDistanceForNextUpdate: CLLocationDistance = 100

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

    typealias RequestSituation = (location: CLLocation, date: Date)
    var lastRequestSituation: RequestSituation?

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if !isMetering {
            roadNameLabel.text = nil
            roadNameLabel.isHidden = true
            canonicalRoadNameLabel.text = nil
            canonicalRoadNameView.isHidden = true
            addressLabel.text = nil
            addressLabel.isHidden = true
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
        lastRequestSituation = nil
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
        let currentDate = Date()

        if let lastRequestSituation = lastRequestSituation {
            guard currentDate >= lastRequestSituation.date + minimumRequestInterval,
                  location.distance(from: lastRequestSituation.location) >= minimumMovementDistanceForNextUpdate
            else { return }

        }

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

        lastRequestSituation = RequestSituation(location: location, date: currentDate)
    }

    func updateLabels(for location: OpenCageClient.Location) {
        updateRoadNameLabels(for: location)
        updateAddressLabel(for: location)
    }

    func updateRoadNameLabels(for location: OpenCageClient.Location) {
        if let popularName = location.road?.popularName {
            roadNameLabel.text = popularName
            canonicalRoadNameLabel.text = canonicalRoadName(for: location)
        } else if let canonicalRoadName = canonicalRoadName(for: location) {
            roadNameLabel.text = canonicalRoadName
            canonicalRoadNameLabel.text = nil
        } else if let unnumberedRouteName = unnumberedRouteName(for: location) {
            roadNameLabel.text = unnumberedRouteName
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

    func canonicalRoadName(for location: OpenCageClient.Location) -> String? {
        guard let road = location.road else { return nil }

        if let roadIdentifier = road.identifier {
            return roadIdentifier
        }

        guard let routeNumber = road.routeNumber else { return nil }

        let address = location.address

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

    func unnumberedRouteName(for location: OpenCageClient.Location) -> String? {
        guard let road = location.road else { return nil }

        switch road.roadType {
        case .trunk:
            return "国道"
        case .primary, .secondary:
            let prefecture = location.address?.prefecture ?? "都道府県"
            return "\(prefecture)道"
        case .tertiary:
            let city = location.address?.city ?? "市町村"
            return "\(city)道"
        default:
            return nil
        }
    }

    func format(_ address: OpenCageClient.Address) -> String {
        return [address.prefecture, address.city, address.suburb, address.neighbourhood].compactMap { $0 }.joined(separator: " ")
    }
}
