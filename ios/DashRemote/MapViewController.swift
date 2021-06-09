//
//  ViewController.swift
//  DashRemote
//
//  Created by Yuji Nakayama on 2020/01/28.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit
import MapKit
import TransitionButton
import DashCloudKit

class MapViewController: UIViewController, MKMapViewDelegate, AccountDelegate {
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var pickUpButton: TransitionButton!

    private var hasInitiallyZoomedToUserLocation = false
    let locationManager = CLLocationManager()

    override func viewDidLoad() {
        super.viewDidLoad()

        Account.default.delegate = self
    }

    deinit {
        // > Before releasing an MKMapView object for which you have set a delegate,
        // > remember to set that object’s delegate property to nil.
        // https://developer.apple.com/documentation/mapkit/mkmapviewdelegate
        mapView.delegate = nil
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        showRequirementsIfNeeded()
    }

    func accountDidSignOut(_ account: Account) {
        showRequirementsIfNeeded()
    }

    func showRequirementsIfNeeded() {
        if PairedVehicle.defaultVehicleID == nil {
            showPairingRequirement()
        } else {
            Account.default.checkSignInState { (signedIn) in
                if signedIn {
                    self.setUpMapView()
                } else {
                    self.showSignInWithApple()
                }
            }
        }
    }

    func showPairingRequirement() {
        performSegue(withIdentifier: "pairingRequirement", sender: nil)
    }

    func showSignInWithApple() {
        DispatchQueue.main.async {
            self.performSegue(withIdentifier: "signInWithApple", sender: nil)
        }
    }

    func setUpMapView() {
        locationManager.requestWhenInUseAuthorization()
    }

    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        guard !hasInitiallyZoomedToUserLocation else { return }
        moveToCurrentLocation(animated: false)
        hasInitiallyZoomedToUserLocation = true
    }

    @IBAction func currentLocationButtonDidTap() {
        moveToCurrentLocation(animated: true)
    }

    func moveToCurrentLocation(animated: Bool) {
        let region = MKCoordinateRegion(center: mapView.userLocation.coordinate, latitudinalMeters: 500, longitudinalMeters: 500)
        mapView.setRegion(region, animated: animated)
    }

    @IBAction func pickUpButtonDidTap() {
        pickUpButton.startAnimation()

        let location = Location(coordinate: mapView.userLocation.coordinate, name: Account.default.givenName)

        location.mapItem { (result) in
            switch result {
            case .success(let mapItem):
                self.share(mapItem: mapItem, url: location.appleMapsURL)
            case .failure:
                self.pickUpButton.stopAnimation(animationStyle: .shake, revertAfterDelay: 1)
            }
        }
    }

    func share(mapItem: MKMapItem, url: URL) {
        guard let vehicleID = PairedVehicle.defaultVehicleID else { return }

        let encoder = SharingItem.Encoder()
        encoder.add(mapItem)
        encoder.add(url)

        let sharingItem = SharingItem(encoder: encoder)

        sharingItem.share(with: vehicleID) { (error) in
            if error != nil {
                self.pickUpButton.stopAnimation(animationStyle: .shake, revertAfterDelay: 1)
            } else {
                self.pickUpButton.stopAnimation(animationStyle: .expand, revertAfterDelay: 1.5) {
                    self.performSegue(withIdentifier: "success", sender: nil)
                }
            }
        }
    }
}
