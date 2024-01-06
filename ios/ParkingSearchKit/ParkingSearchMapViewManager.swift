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
    func parkingSearchMapViewManager(_ manager: ParkingSearchMapViewManager, didSelectParking parking: ParkingProtocol, forReservationWebPage url: URL)
    func parkingSearchMapViewManager(_ manager: ParkingSearchMapViewManager, didSelectParkingForSearchingOnWeb parking: ParkingProtocol)
}

@MainActor
public class ParkingSearchMapViewManager: NSObject {
    static let pinAnnotationViewIdentifier = String(describing: MKPinAnnotationView.self)
    static let parkingAnnotationViewIdentifier = String(describing: ParkingAnnotationView.self)

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

            let newAndOldDestinationsAreInSameArea: Bool

            if let previousDestination = oldValue, destination.distance(from: previousDestination) <= 1000 {
                newAndOldDestinationsAreInSameArea = true
            } else {
                newAndOldDestinationsAreInSameArea = false
            }

            startSearchingParkings(resetEntranceDateToExpectedArrivalDate: !newAndOldDestinationsAreInSameArea)
        }
    }

    public private(set) var isSearching = false {
        didSet {
            updateActivityIndicator()
        }
    }

    private var destinationAnnotation: MKPointAnnotation?

    private var parkingAnnotations: [ParkingAnnotation] {
        return mapView.annotations.filter { $0 is ParkingAnnotation } as! [ParkingAnnotation]
    }

    private let pppark = PPPark(clientKey: "IdkUdfal673kUdj00")

    private var currentSearchTask: Task<Void, Never>?

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

        optionsView.entranceDatePicker.addTarget(self, action: #selector(parkingTimeConfigurationDidChange), for: .valueChanged)
        optionsView.entranceTimePicker.addTarget(self, action: #selector(parkingTimeConfigurationDidChange), for: .valueChanged)
        optionsView.timeDurationPicker.addTarget(self, action: #selector(parkingTimeConfigurationDidChange), for: .valueChanged)
    }

    public func viewWillAppear() {
        updateActivityIndicator()
    }

    public func viewDidDissapear() {
    }

    public func clearMapView() {
        currentSearchTask?.cancel()

        removeParkings()

        if let destinationAnnotation = destinationAnnotation {
            mapView.removeAnnotation(destinationAnnotation)
        }

        destinationAnnotation = nil
    }

    @objc private func parkingTimeConfigurationDidChange() {
        startSearchingParkings(resetEntranceDateToExpectedArrivalDate: false)
    }

    private func startSearchingParkings(resetEntranceDateToExpectedArrivalDate: Bool) {
        currentSearchTask?.cancel()

        removeParkings()
        addDestinationAnnotationIfNeeded()

        currentSearchTask = Task {
            isSearching = true

            do {
                if (resetEntranceDateToExpectedArrivalDate) {
                    let arrivalDate = try await calculateExpectedArrivalDate()
                    optionsView.setEntranceDate(arrivalDate, animated: true)
                }

                guard let entranceDate = optionsView.entranceDate,
                      let timeDuration = optionsView.timeDurationPicker.duration
                else { return }

                let parkings = try await ParkingSearch(
                    destination: destination,
                    entranceDate: entranceDate,
                    exitDate: entranceDate + timeDuration
                ).search()

                showParkings(parkings)
            } catch {
                logger.error(error)
            }

            if !Task.isCancelled {
                isSearching = false
            }
        }
    }

    private func updateActivityIndicator() {
        guard let destinationAnnotation = destinationAnnotation else { return }

        if isSearching {
            mapView.view(for: destinationAnnotation)?.canShowCallout = true
            mapView.selectAnnotation(destinationAnnotation, animated: true)
        } else {
            mapView.deselectAnnotation(destinationAnnotation, animated: true)
            mapView.view(for: destinationAnnotation)?.canShowCallout = false
        }
    }

    private func addDestinationAnnotationIfNeeded() {
        guard destinationAnnotation == nil else { return }

        let annotation = DestinationAnnotation()
        annotation.coordinate = destination
        annotation.title = "周辺の駐車場を検索中"

        mapView.addAnnotation(annotation)
        mapView.selectAnnotation(annotation, animated: true)

        let region = MKCoordinateRegion(
            center: annotation.coordinate,
            latitudinalMeters: preferredMaxDistanceFromDestinationToParking * 2,
            longitudinalMeters: preferredMaxDistanceFromDestinationToParking * 2
        )
        mapView.setRegion(region, animated: true)

        destinationAnnotation = annotation
    }

    private func calculateExpectedArrivalDate() async throws -> Date {
        let request = MKDirections.Request()
        request.source = MKMapItem.forCurrentLocation()
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .automobile

        let response = try await MKDirections(request: request).calculateETA()
        return response.expectedArrivalDate
    }

    private func showParkings(_ parkings: [ParkingProtocol]) {
        let openParkings = parkings.filter { !($0.isClosedNow == true) }
        addParkings(openParkings)

        let preferredParkingAnnotations = preferredParkingAnnotations
        setMapRegion(for: preferredParkingAnnotations)
        selectBestParking(from: preferredParkingAnnotations)
    }

    private func addParkings(_ parkings: [ParkingProtocol]) {
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
        if let view = mapView.dequeueReusableAnnotationView(withIdentifier: Self.parkingAnnotationViewIdentifier) as? ParkingAnnotationView {
            view.annotation = annotation
            return view
        } else {
            let view = ParkingAnnotationView(annotation: annotation, reuseIdentifier: Self.parkingAnnotationViewIdentifier)
            view.callout.nameLabelControl.addInteraction(UIContextMenuInteraction(delegate: self))
            view.callout.reservationButton.addTarget(self, action: #selector(notifyDelegateOfReservationPage), for: .touchUpInside)
            return view
        }
    }

    private func viewForDestinationAnnotation(_ annotation: MKAnnotation) -> MKAnnotationView {
        let view = mapView.dequeueReusableAnnotationView(withIdentifier: Self.pinAnnotationViewIdentifier, for: annotation) as! MKPinAnnotationView
        view.animatesDrop = true
        view.canShowCallout = true
        view.displayPriority = .required
        // Show DestinationAnnotation over other annotations such as PointOfInterestAnnotation
        view.zPriority = .init(MKAnnotationViewZPriority.defaultUnselected.rawValue + 1)

        let activityIndicatorView = UIActivityIndicatorView()
        activityIndicatorView.startAnimating()
        activityIndicatorView.sizeToFit()
        view.rightCalloutAccessoryView = activityIndicatorView

        view.leftCalloutAccessoryView = UIView() // To balance the horizontal edge spacings

        return view
    }

    @objc private func notifyDelegateOfReservationPage() {
        guard let parking = (mapView.selectedAnnotations.first as? ParkingAnnotation)?.parking else { return }
        guard let reservationURL = parking.reservation?.url else { return }
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
