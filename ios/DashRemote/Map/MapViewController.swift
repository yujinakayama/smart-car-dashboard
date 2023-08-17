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

class MapViewController: UIViewController, MKMapViewDelegate {
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var pickUpButton: TransitionButton!

    private var hasInitiallyZoomedToUserLocation = false

    let locationManager = {
        let locationManager = CLLocationManager()
        locationManager.pausesLocationUpdatesAutomatically = false
        return locationManager
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        Account.default.delegate = self
        locationManager.requestWhenInUseAuthorization()
    }

    deinit {
        // > Before releasing an MKMapView object for which you have set a delegate,
        // > remember to set that object’s delegate property to nil.
        // https://developer.apple.com/documentation/mapkit/mkmapviewdelegate
        mapView.delegate = nil
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

        let rendezvousPoint = RendezvousPoint(
            coordinate: mapView.userLocation.coordinate,
            name: Account.default.givenName
        )

        rendezvousPoint.mapItem { (result) in
            switch result {
            case .success(let mapItem):
                self.share(mapItem: mapItem, url: rendezvousPoint.appleMapsURL)
            case .failure:
                self.pickUpButton.stopAnimation(animationStyle: .shake, revertAfterDelay: 1)
            }
        }
    }

    func share(mapItem: MapItem, url: URL) {
        guard let vehicleID = PairedVehicle.defaultVehicleID else { return }

        let encoder = Item.Encoder()
        encoder.add(mapItem)
        encoder.add(url)
        let item = Item(encoder: encoder)

        cloudClient.add(item, toInboxOf: vehicleID) { (error) in
            if error != nil {
                self.pickUpButton.stopAnimation(animationStyle: .shake, revertAfterDelay: 1)
            } else {
                self.pickUpButton.stopAnimation(animationStyle: .expand, revertAfterDelay: 1.5) {
                    self.performSegue(withIdentifier: "success", sender: nil)
                }
            }
        }
    }

    lazy var cloudClient = DashCloudClient()
}

extension MapViewController: AccountDelegate {
    func accountDidSignOut(_ account: Account) {
        dismiss(animated: true)
    }
}
