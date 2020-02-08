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
import DashShareKit

class MapViewController: UIViewController, MKMapViewDelegate, SignInWithAppleViewControllerDelegate {
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var pickUpButton: TransitionButton!

    private var hasInitiallyZoomedToUserLocation = false
    let locationManager = CLLocationManager()

    override func viewDidLoad() {
        super.viewDidLoad()

        Account.default.checkSignInState { (signedIn) in
            if signedIn {
                self.setUpMapView()
            } else {
                DispatchQueue.main.async {
                    self.performSegue(withIdentifier: "signInWithApple", sender: nil)
                }
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

    @IBAction func pickUpButtonDidTap() {
        pickUpButton.startAnimation()

        let currentUserLocation = mapView.userLocation

        let encoder = SharingItem.Encoder()
        encoder.add(mapItem(for: currentUserLocation))
        encoder.add(appleMapsURL(for: currentUserLocation, name: Account.default.givenName))

        let sharingItem = SharingItem(encoder: encoder)
        sharingItem.share { (error) in
            if error != nil {
                self.pickUpButton.stopAnimation(animationStyle: .shake, revertAfterDelay: 1)
            } else {
                self.pickUpButton.stopAnimation(animationStyle: .expand, revertAfterDelay: 1.5) {
                    self.performSegue(withIdentifier: "success", sender: nil)
                }
            }
        }
    }

    func mapItem(for userLocation: MKUserLocation) -> MKMapItem {
        let placemark = MKPlacemark(coordinate: userLocation.coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = Account.default.givenName
        return mapItem
    }

    func appleMapsURL(for userLocation: MKUserLocation, name: String?) -> URL {
        let coordinate = userLocation.coordinate

        var components = URLComponents(string: "https://maps.apple.com/")!

        var queryItems = [URLQueryItem(name: "ll", value: "\(coordinate.latitude),\(coordinate.longitude)")]

        if let name = name {
            queryItems.append(URLQueryItem(name: "q", value: name))
        }

        components.queryItems = queryItems

        return components.url!
    }
}
