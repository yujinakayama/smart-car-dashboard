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
    func parkingSearchMapViewManager(_ manager: ParkingSearchMapViewManager, didSelectParkingForSearchingOnWeb parking: Parking)
}

public class ParkingSearchMapViewManager: NSObject {
    static let pinAnnotationViewIdentifier = "MKPinAnnotationView"

    public weak var delegate: ParkingSearchMapViewManagerDelegate?

    public let mapView: MKMapView

    public let optionsView = ParkingSearchOptionsView()

    // 5 minutes walk with speed 80m/min
    // (though actual distance must be longer since this is based on linear distance)
    public var preferredMaxDistanceFromDestinationToParking: CLLocationDistance = 400

    public var destination: CLLocationCoordinate2D! {
        didSet {
            clearMapView()

            guard let destination = destination else { return }

            addDestinationAnnotation()

            if let previousDestination = oldValue,
               CLLocation(coordinate: destination).distance(from: CLLocation(coordinate: previousDestination)) <= 1000
            {
                searchParkings()
            } else {
                calculateExpectedTravelTime { (travelTime) in
                    DispatchQueue.main.async {
                        if let travelTime = travelTime {
                            self.optionsView.entranceDatePicker.date = Date() + travelTime
                        }

                        self.searchParkings()
                    }
                }
            }
        }
    }

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

    private let ppparkClient = PPParkClient(clientKey: "IdkUdfal673kUdj00")

    private var currentSearchTask: URLSessionTask?

    public init(mapView: MKMapView) {
        self.mapView = mapView
        super.init()
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

        let region = MKCoordinateRegion(
            center: annotation.coordinate,
            latitudinalMeters: preferredMaxDistanceFromDestinationToParking * 2,
            longitudinalMeters: preferredMaxDistanceFromDestinationToParking * 2
        )
        mapView.setRegion(region, animated: true)

        destinationAnnotation = annotation
    }

    private func calculateExpectedTravelTime(completion: @escaping (TimeInterval?) -> Void) {
        let request = MKDirections.Request()
        request.source = MKMapItem.forCurrentLocation()
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .automobile

        MKDirections(request: request).calculate { (response, error) in
            if let error = error {
                logger.error(error)
            }

            completion(response?.routes.first?.expectedTravelTime)
        }
    }

    @objc private func searchParkings() {
        currentSearchTask?.cancel()

        removeParkings()

        guard let timeDuration = optionsView.timeDurationPicker.selectedDuration else { return }

        if let destinationAnnotation = destinationAnnotation {
            self.mapView.view(for: destinationAnnotation)?.canShowCallout = true
            mapView.selectAnnotation(destinationAnnotation, animated: true)
        }

        currentSearchTask = ppparkClient.searchParkings(
            around: destination,
            entranceDate: optionsView.entranceDatePicker.date,
            exitDate: optionsView.entranceDatePicker.date + timeDuration
        ) { [weak self] (result) in
            guard let self = self else { return }

            var isCancelled = false

            switch result {
            case .success(let parkings):
                DispatchQueue.main.async {
                    self.showParkings(parkings)
                }
            case .failure(let error):
                logger.error(error)

                if let urlError = error as? URLError, urlError.code == .cancelled {
                    isCancelled = true
                }
            }

            if !isCancelled, let destinationAnnotation = self.destinationAnnotation {
                DispatchQueue.main.async {
                    self.mapView.deselectAnnotation(destinationAnnotation, animated: true)
                    self.mapView.view(for: destinationAnnotation)?.canShowCallout = false
                }
            }
        }
    }

    private func showParkings(_ parkings: [Parking]) {
        let openParkings = parkings.filter { !$0.isClosed }
        addParkings(openParkings)

        let preferredParkingAnnotations = preferredParkingAnnotations
        setMapRegion(for: preferredParkingAnnotations)
        selectBestParking(from: preferredParkingAnnotations)
    }

    private func addParkings(_ parkings: [Parking]) {
        let annotations = parkings.map { ParkingAnnotation($0) }
        mapView.addAnnotations(annotations)
    }

    private func removeParkings() {
        mapView.removeAnnotations(parkingAnnotations)
    }

    private var preferredParkingAnnotations: [ParkingAnnotation] {
        let preferredParkingAnnotations = parkingAnnotations.filter { (annotation) in
            annotation.parking.distance <= preferredMaxDistanceFromDestinationToParking
        }

        if preferredParkingAnnotations.isEmpty {
            if let nearestParkingAnnotation = parkingAnnotations.min(by: { $0.parking.distance < $1.parking.distance }) {
                return [nearestParkingAnnotation]
            } else {
                return []
            }
        } else {
            return preferredParkingAnnotations
        }
    }

    private func setMapRegion(for parkingAnnotations: [ParkingAnnotation]) {
        let parkingCoordinates = parkingAnnotations.map({ $0.coordinate })

        guard let region = regionThatContains(parkingCoordinates, center: destination) else { return }

        let extendedRegion = MKCoordinateRegion(
            center: region.center,
            span: MKCoordinateSpan(
                latitudeDelta: region.span.latitudeDelta * 1.15,
                longitudeDelta: region.span.longitudeDelta * 1.15
            )
        )

        mapView.setRegion(extendedRegion, animated: true)
    }

    private func selectBestParking(from parkingAnnotations: [ParkingAnnotation]) {
        let bestParkingAnnotation = parkingAnnotations.min { (a, b) in
            if a.parking.rank == b.parking.rank {
                return a.parking.distance < b.parking.distance
            } else {
                return (a.parking.rank ?? Int.max) < (b.parking.rank ?? Int.max)
            }
        }

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
            view.callout.nameLabelControl.addInteraction(UIContextMenuInteraction(delegate: self))
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

extension ParkingSearchMapViewManager: UIContextMenuInteractionDelegate {
    public func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        let actionProvider: UIContextMenuActionProvider = { (suggestedActions) in
            let action = UIAction(title: "Webで検索", image: UIImage(systemName: "magnifyingglass")) { (action) in
                guard let parking = (self.mapView.selectedAnnotations.first as? ParkingAnnotation)?.parking else { return }
                self.delegate?.parkingSearchMapViewManager(self, didSelectParkingForSearchingOnWeb: parking)
            }

            return UIMenu(title: "", children: [action])
        }

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil, actionProvider: actionProvider)
    }
}

fileprivate class DestinationAnnotation: MKPointAnnotation {
}

fileprivate func regionThatContains(_ coordinates: [CLLocationCoordinate2D], center: CLLocationCoordinate2D) -> MKCoordinateRegion? {
    if coordinates.isEmpty {
        return nil
    }

    var maxLatitudeDifference: CLLocationDegrees = 0
    var maxLongitudeDifference: CLLocationDegrees = 0

    for coordinate in coordinates {
        let latitudeDifference = abs(coordinate.latitude - center.latitude)

        if latitudeDifference > maxLatitudeDifference {
            maxLatitudeDifference = latitudeDifference
        }

        let longitudeDifference = abs(coordinate.longitude - center.longitude)

        if longitudeDifference > maxLongitudeDifference {
            maxLongitudeDifference = longitudeDifference
        }
    }

    let span = MKCoordinateSpan(latitudeDelta: maxLatitudeDifference * 2, longitudeDelta: maxLongitudeDifference * 2)
    return MKCoordinateRegion(center: center, span: span)
}

fileprivate extension CLLocation {
    convenience init(coordinate: CLLocationCoordinate2D) {
        self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}
