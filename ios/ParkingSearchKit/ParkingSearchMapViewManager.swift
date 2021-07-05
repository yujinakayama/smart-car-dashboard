//
//  ParkingSearchMapViewManager.swift
//  ParkingSearchKit
//
//  Created by Yuji Nakayama on 2021/07/03.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import Foundation
import MapKit

public protocol ParkingSearchMapViewManagerDelegate: NSObjectProtocol {
    func parkingSearchMapViewManager(_ manager: ParkingSearchMapViewManager, didSelectParking parking: Parking, forReservationWebPage url: URL)
}

public class ParkingSearchMapViewManager {
    static let pinAnnotationViewIdentifier = "MKPinAnnotationView"

    public weak var delegate: ParkingSearchMapViewManagerDelegate?

    public let mapView: MKMapView

    public let optionsView = ParkingSearchOptionsView()

    private var annotations: [MKAnnotation] {
        var annotations: [MKAnnotation] = parkingAnnotations

        if let destinationAnnotation = destinationAnnotation {
            annotations.append(destinationAnnotation)
        }

        return annotations
    }

    private var destinationAnnotation: MKPointAnnotation?

    private var parkingAnnotations: [ParkingAnnotation] {
        return mapView.annotations.filter { $0 is ParkingAnnotation } as! [ParkingAnnotation]
    }

    private var destination: CLLocationCoordinate2D!

    private let ppparkClient = PPParkClient(clientKey: "IdkUdfal673kUdj00")

    private var currentSearchTask: URLSessionTask?

    public init(mapView: MKMapView) {
        self.mapView = mapView
        configureViews()
    }

    deinit {
        currentSearchTask?.cancel()
    }

    private func configureViews() {
        mapView.register(MKPinAnnotationView.self, forAnnotationViewWithReuseIdentifier: Self.pinAnnotationViewIdentifier)

        optionsView.entranceDatePicker.addTarget(self, action: #selector(searchParkings), for: .valueChanged)
        optionsView.timeDurationPicker.addTarget(self, action: #selector(searchParkings), for: .valueChanged)
    }

    public func setDestination(_ destionation: CLLocationCoordinate2D) {
        self.destination = destionation
        applyDestination()
    }

    public func clearMapView() {
        currentSearchTask?.cancel()

        mapView.removeAnnotations(annotations)
        destinationAnnotation = nil
    }

    private func applyDestination() {
        clearMapView()

        addDestinationAnnotation()

        calculateExpectedTravelTime { (travelTime) in
            DispatchQueue.main.async {
                if let travelTime = travelTime {
                    self.optionsView.entranceDatePicker.date = Date() + travelTime
                }

                self.searchParkings()
            }
        }
    }

    private func addDestinationAnnotation() {
        let annotation = DestinationAnnotation()
        annotation.coordinate = destination
        annotation.title = "周辺の駐車場を検索中"

        mapView.addAnnotation(annotation)

        DispatchQueue.main.async {
            self.mapView.selectAnnotation(annotation, animated: true)
        }

        destinationAnnotation = annotation
    }

    private func calculateExpectedTravelTime(completion: @escaping (TimeInterval?) -> Void) {
        let request = MKDirections.Request()
        request.source = MKMapItem.forCurrentLocation()
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .automobile

        MKDirections(request: request).calculate { (response, error) in
            if let error = error {
                print(error)
            }

            completion(response?.routes.first?.expectedTravelTime)
        }
    }

    @objc private func searchParkings() {
        currentSearchTask?.cancel()

        removeParkings()

        guard let timeDuration = optionsView.timeDurationPicker.selectedDuration else { return }

        if let destinationAnnotation = destinationAnnotation {
            mapView.selectAnnotation(destinationAnnotation, animated: true)
        }

        currentSearchTask = ppparkClient.searchParkings(
            around: destination,
            entranceDate: optionsView.entranceDatePicker.date,
            exitDate: optionsView.entranceDatePicker.date + timeDuration
        ) { [weak self] (result) in
            guard let self = self else { return }

            switch result {
            case .success(let parkings):
                DispatchQueue.main.async {
                    self.showParkings(parkings)
                }
            case .failure(let error):
                print(error)
            }

            if let destinationAnnotation = self.destinationAnnotation {
                self.mapView.view(for: destinationAnnotation)?.canShowCallout = false
            }
        }
    }

    private func showParkings(_ parkings: [Parking]) {
        let openParkings = parkings.filter { !$0.isClosed }
        addParkings(openParkings)
        mapView.showAnnotations(annotations, animated: true)
        selectBestParking()
    }

    private func addParkings(_ parkings: [Parking]) {
        let annotations = parkings.map { ParkingAnnotation($0) }
        mapView.addAnnotations(annotations)
    }

    private func removeParkings() {
        mapView.removeAnnotations(parkingAnnotations)
    }

    private func selectBestParking() {
        let cheapstParkingAnnotations = parkingAnnotations.filter { $0.parking.rank == 1 }
        let bestParkingAnnotation = cheapstParkingAnnotations.min { $0.parking.distance < $1.parking.distance }

        if let bestParkingAnnotation = bestParkingAnnotation {
            mapView.selectAnnotation(bestParkingAnnotation, animated: true)
        }
    }

    public func view(for annotation: MKAnnotation) -> MKAnnotationView? {
        switch annotation {
        case let parkingAnnotation as ParkingAnnotation:
            return viewForParkingAnnotation(parkingAnnotation)
        case is DestinationAnnotation:
            return viewForDestinationAnnotation(annotation)
        default:
            return nil
        }
    }

    private func viewForParkingAnnotation(_ annotation: ParkingAnnotation) -> MKAnnotationView {
        if let view = mapView.dequeueReusableAnnotationView(withIdentifier: "MKMarkerAnnotationView") as? ParkingAnnotationView {
            view.annotation = annotation
            return view
        } else {
            let view = ParkingAnnotationView(annotation: annotation, reuseIdentifier: "MKMarkerAnnotationView")
            view.callout.reservationButton.addTarget(self, action: #selector(notifyDelegateOfReservationPage), for: .touchUpInside)
            return view
        }
    }

    private func viewForDestinationAnnotation(_ annotation: MKAnnotation) -> MKAnnotationView {
        let view = mapView.dequeueReusableAnnotationView(withIdentifier: "MKPinAnnotationView", for: annotation) as! MKPinAnnotationView
        view.animatesDrop = true
        view.canShowCallout = true
        view.displayPriority = .required

        let activityIndicatorView = UIActivityIndicatorView()
        activityIndicatorView.startAnimating()
        activityIndicatorView.sizeToFit()
        view.rightCalloutAccessoryView = activityIndicatorView

        view.leftCalloutAccessoryView = UIView() // To balance the horizontal edge spacings

        return view
    }

    @objc private func notifyDelegateOfReservationPage() {
        guard let parking = (mapView.selectedAnnotations.first as? ParkingAnnotation)?.parking else { return }
        guard let reservationURL = parking.reservationInfo?.url else { return }
        delegate?.parkingSearchMapViewManager(self, didSelectParking: parking, forReservationWebPage: reservationURL)
    }
}

fileprivate class DestinationAnnotation: MKPointAnnotation {
}
