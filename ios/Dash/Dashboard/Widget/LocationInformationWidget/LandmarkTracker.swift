//
//  LandmarkTracker.swift
//  Dash
//
//  Created by Yuji Nakayama on 2023/07/05.
//  Copyright © 2023 Yuji Nakayama. All rights reserved.
//

import Foundation
import MapKit
import Turf

class LandmarkTracker: NSObject {
    enum Policy: CustomStringConvertible {
        case nearest
        case onlyForward(forwardAngle: Double)
        
        var description: String {
            switch self {
            case .nearest:
                return "nearest"
            case .onlyForward:
                return "onlyForward"
            }
        }
    }

    static let shared = LandmarkTracker()
 
    private var lastMostInterestingLandmark: MKMapItem?
    private var lastMostInterestingLandmarkSearchTime :Date?
    
    private var landmarkCollection: LandmarkCollection?

    func relativeLocationToMostInterestingLandmark(around location: CLLocation, with policy: Policy) async -> LandmarkRelativeLocation? {
        // Within 6 seconds from last nearest landmark search,
        // use the cached landmark.
        if let lastMostInterestingLandmark = lastMostInterestingLandmark,
           let lastMostInterestingLandmarkSearchTime = lastMostInterestingLandmarkSearchTime,
           lastMostInterestingLandmarkSearchTime.distance(to: Date()) < 6
        {
            return LandmarkRelativeLocation(landmark: lastMostInterestingLandmark, currentLocation: location)
        }

        guard let landmarkCollection = await updateLandmarkCollectionIfNeeded(around: location) else {
            return nil
        }
        
        let relativeLocations = landmarkCollection.relativeLocations(from: location)
        let bestRelativeLocation = extractMostInterestingLandmark(from: relativeLocations, with: policy)
        lastMostInterestingLandmark = bestRelativeLocation?.landmark
        lastMostInterestingLandmarkSearchTime = Date()
        return bestRelativeLocation
    }

    func extractMostInterestingLandmark(from relativeLocations: [LandmarkRelativeLocation], with policy: Policy) -> LandmarkRelativeLocation? {
        switch policy {
        case .nearest:
            return relativeLocations.sorted { $0.distance < $1.distance }.first
        case .onlyForward(let forwardAngle):
            let angleThreshold = forwardAngle / 2
            let forwardRelativeLocation = relativeLocations.filter { $0.angle <= angleThreshold || $0.angle >= (360 - angleThreshold) }
            return forwardRelativeLocation.sorted { $0.distance < $1.distance }.first
        }
    }

    private func updateLandmarkCollectionIfNeeded(around center: CLLocation) async -> LandmarkCollection? {
        if let landmarkCollection = landmarkCollection {
            if landmarkCollection.center.distance(from: center) > 1000 {
                await updateLandmarkCollection(around: center)
            }
        } else {
            await updateLandmarkCollection(around: center)
        }
        
        return landmarkCollection
    }
    
    private func updateLandmarkCollection(around center: CLLocation) async {
        logger.info()

        let request = MKLocalSearch.Request()
        request.region = MKCoordinateRegion(center: center.coordinate, latitudinalMeters: 5000, longitudinalMeters: 5000)
        request.naturalLanguageQuery = "Train Stations"
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.publicTransport])
        request.resultTypes = .pointOfInterest
        
        let response = try? await MKLocalSearch(request: request).start()
        guard let mapItems = response?.mapItems else { return }
        landmarkCollection = LandmarkCollection(center: center, landmarks: mapItems)
    }
}

struct LandmarkCollection {
    var center: CLLocation
    var landmarks: [MKMapItem]
    
    init(center: CLLocation, landmarks: [MKMapItem]) {
        self.center = center
        self.landmarks = landmarks.filter { $0.placemark.location != nil }
    }
    
    // Consider improving NNS algorithm
    // https://rahvee.gitlab.io/comparison-nearest-neighbor-search/
    func relativeLocations(from location: CLLocation) -> [LandmarkRelativeLocation] {
        return landmarks.map { LandmarkRelativeLocation(landmark: $0, currentLocation: location) }
    }
}

struct LandmarkRelativeLocation {
    var landmark: MKMapItem
    var currentLocation: CLLocation
    var distance: CLLocationDistance
    var angle: LocationDegrees
    
    init(landmark: MKMapItem, currentLocation: CLLocation) {
        self.landmark = landmark
        self.currentLocation = currentLocation
        self.distance = landmark.placemark.location!.distance(from: currentLocation)

        let azimuth = currentLocation.coordinate.direction(to: landmark.placemark.coordinate)
        self.angle = (azimuth - currentLocation.course + 360).truncatingRemainder(dividingBy: 360)
    }
}

fileprivate extension CLLocationCoordinate2D {
    func azimuth(to destination: CLLocationCoordinate2D) -> LocationDegrees {
        let sourceLatitude = self.latitude.toRadians()
        let sourceLongitude = self.longitude.toRadians()
        let destinationLatitude = destination.latitude.toRadians()
        let destinationLongitude = destination.longitude.toRadians()
        
        let longitudeDifference = destinationLongitude - sourceLongitude
        let y = sin(longitudeDifference) * cos(destinationLatitude)
        let x = cos(sourceLatitude) * sin(destinationLatitude) - sin(sourceLatitude) * cos(destinationLatitude) * cos(longitudeDifference)
        let angleInRadian = atan2(y, x).truncatingRemainder(dividingBy: .pi * 2)

        return angleInRadian.toDegrees()
    }
}
