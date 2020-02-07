//
//  ViewController.swift
//  DashRemote
//
//  Created by Yuji Nakayama on 2020/01/28.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit
import MapKit

class MapViewController: UIViewController, MKMapViewDelegate, SignInWithAppleViewControllerDelegate {
    @IBOutlet weak var mapView: MKMapView!

    private var hasInitiallyZoomedToUserLocation = false
    let locationManager = CLLocationManager()

    override func viewDidLoad() {
        super.viewDidLoad()

        mapView.delegate = self

        Account.default.checkSignInState { (signedIn) in
            if signedIn {
                self.setUpMapView()
            } else {
                self.performSegue(withIdentifier: "signInWithApple", sender: nil)
            }
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
        case "signInWithApple":
            let signInWithAppleViewController = segue.destination as! SignInWithAppleViewController
            signInWithAppleViewController.delegate = self
        default:
            break
        }
    }

    func signInWithAppleViewControllerDidCompleteAuthorization(_ viewController: SignInWithAppleViewController) {
        setUpMapView()
    }

    func setUpMapView() {
        locationManager.requestWhenInUseAuthorization()
    }

    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        guard !hasInitiallyZoomedToUserLocation else { return }

        let region = MKCoordinateRegion(center: userLocation.coordinate, latitudinalMeters: 500, longitudinalMeters: 500)
        mapView.region = region
        hasInitiallyZoomedToUserLocation = true
    }
}
