//
//  AltitudeWidgetViewController.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/12/30.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit
import CoreLocation

class AltitudeWidgetViewController: UIViewController, CLLocationManagerDelegate {
    @IBOutlet weak var altitudeLabel: UILabel!

    lazy var locationManager: CLLocationManager = {
        let locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        return locationManager
    }()

    var isMetering = false

    override func viewDidLoad() {
        super.viewDidLoad()
        altitudeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 72, weight: .medium)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if !isMetering {
            altitudeLabel.text = "-"
            startMetering()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        stopMetering()
        super.viewDidDisappear(animated)
    }

    func startMetering() {
        logger.info()

        isMetering = true

        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.startUpdatingLocation()
        default:
            locationManager.requestWhenInUseAuthorization()
        }
    }

    func stopMetering() {
        logger.info()
        locationManager.stopUpdatingLocation()
        isMetering = false
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        logger.info(manager.authorizationStatus.rawValue)

        guard isMetering else { return }

        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.startUpdatingLocation()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        logger.info()
        guard let location = locations.last else { return }
        update(location: location)
    }

    func update(location: CLLocation) {
        guard location.verticalAccuracy >= 0 else {
            altitudeLabel.text = "-"
            return
        }

        altitudeLabel.text = String(format: "%1.0f", round(location.altitude))
    }
}
