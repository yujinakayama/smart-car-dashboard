//
//  MapKitParkingSearch.swift
//  ParkingSearchKit
//
//  Created by Yuji Nakayama on 2022/02/26.
//  Copyright © 2022 Yuji Nakayama. All rights reserved.
//

import Foundation
import MapKit

class MapKitParkingSearch {
    let destination: CLLocationCoordinate2D
    let entranceDate: Date
    let exitDate: Date

    required init(destination: CLLocationCoordinate2D, entranceDate: Date, exitDate: Date) {
        self.destination = destination
        self.entranceDate = entranceDate
        self.exitDate = exitDate
    }

    func search() async throws -> [MapKitParking] {
        async let parkingsWithNatualLanguageQuery = searchParkingsWithNaturalLanguageQuery()
        async let parkingsWithPointOfInterestFilterRequest = searchParkingsWithPointOfInterestRequest()

        let mergedParkings = Set(try await parkingsWithNatualLanguageQuery).union(try await parkingsWithPointOfInterestFilterRequest)
        let parkingsForCars: [MapKitParking] = mergedParkings.filter { $0.isForCars }

        if considersParkingMetersAvailable {
            return parkingsForCars
        } else {
            return parkingsForCars.filter { !$0.isParkingMeter }
        }
    }

    // Returns parkings including ones not returned with MKLocalPointsOfInterestRequest.
    // Returned items tend to scattered in larger region.
    private func searchParkingsWithNaturalLanguageQuery() async throws -> [MapKitParking] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "駐車場"
        request.region = .init(center: destination, latitudinalMeters: 1000, longitudinalMeters: 1000)
        request.resultTypes = .pointOfInterest

        do {
            let response = try await MKLocalSearch(request: request).start()
            return response.mapItems.map { MapKitParking(mapItem: $0, destination: destination) }
        } catch MKError.placemarkNotFound {
            return []
        }
    }

    // Returns parkings including ones not returned with MKLocalSearch.Request (e.g. parking meters, parking entrance, and non-car parkings).
    // Returned items tend to be closed to the center point.
    private func searchParkingsWithPointOfInterestRequest() async throws -> [MapKitParking] {
        let request = MKLocalPointsOfInterestRequest(center: destination, radius: 1000)
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.parking])

        do {
            let response = try await MKLocalSearch(request: request).start()
            return response.mapItems.map { MapKitParking(mapItem: $0, destination: destination) }
        } catch MKError.placemarkNotFound {
            return []
        }
    }

    private var considersParkingMetersAvailable: Bool {
        // Maximum parking duration for parking meters is 60 min:
        // https://www.police.pref.kanagawa.jp/mes/mesf4002.htm
        guard entranceDate.distance(to: exitDate) <= 60 * 60 else { return false }

        // Most parking meters are available in 9:00-19:00 or 8:00-20:00
        let availableTimeRange = Time(hour: 9, minute: 0)...Time(hour: 19, minute: 0)
        return availableTimeRange.contains(entranceDate.time) && availableTimeRange.contains(exitDate.time)
    }
}
