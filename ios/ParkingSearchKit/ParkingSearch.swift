//
//  ParkingSearch.swift
//  ParkingSearchKit
//
//  Created by Yuji Nakayama on 2022/01/20.
//  Copyright © 2022 Yuji Nakayama. All rights reserved.
//

import Foundation
import CoreLocation
import MapKit

class ParkingSearch {
    static let aggregationDistance: CLLocationDistance = 5

    let destination: CLLocationCoordinate2D
    let entranceDate: Date
    let exitDate: Date

    private let pppark = PPPark(clientKey: "IdkUdfal673kUdj00")

    init(destination: CLLocationCoordinate2D, entranceDate: Date, exitDate: Date) {
        self.destination = destination
        self.entranceDate = entranceDate
        self.exitDate = exitDate
    }

    func start() async throws -> [ParkingProtocol] {
        async let ppparkParkings = searchParkingsWithPPPark()
        async let mapKitParkings = searchParkingsWithMapKit()
        return aggregate(ppparkParkings: try await ppparkParkings, mapKitParkings: try await mapKitParkings)
    }

    private func searchParkingsWithPPPark() async throws -> [PPPark.Parking] {
        return try await pppark.searchParkings(
            around: destination,
            entranceDate: entranceDate,
            exitDate: exitDate
        )
    }

    private func searchParkingsWithMapKit() async throws -> [MapKitParking] {
        async let parkingWithNatualLanguageQuery = searchParkingsWithMapKitNaturalLanguageQuery()
        async let parkingWithPointOfInterestFilterRequest = searchParkingsWithMapKitPointOfInterestRequest()

        let mergedParkings = Set(try await parkingWithNatualLanguageQuery).union(try await parkingWithPointOfInterestFilterRequest)
        let parkingsForCars: [MapKitParking] = mergedParkings.filter { $0.isForCars }

        if considersParkingMetersAvailable {
            return parkingsForCars
        } else {
            return parkingsForCars.filter { !$0.isParkingMeter }
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

    // Returns parkings including ones not returned with MKLocalPointsOfInterestRequest.
    // Returned items tend to scattered in larger region.
    private func searchParkingsWithMapKitNaturalLanguageQuery() async throws -> [MapKitParking] {
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
    private func searchParkingsWithMapKitPointOfInterestRequest() async throws -> [MapKitParking] {
        let request = MKLocalPointsOfInterestRequest(center: destination, radius: 1000)
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.parking])

        do {
            let response = try await MKLocalSearch(request: request).start()
            return response.mapItems.map { MapKitParking(mapItem: $0, destination: destination) }
        } catch MKError.placemarkNotFound {
            return []
        }
    }

    private func aggregate(ppparkParkings: [PPPark.Parking], mapKitParkings: [MapKitParking]) -> [ParkingProtocol] {
        logger.debug("Removing MapKit parkings that are duplications of PPPark parkings")
        let parkingsListedOnlyOnMapKit = mapKitParkings.filter { (mapKitParking) in
            !ppparkParkings.contains { (ppparkParking) in
                assumesParkingsAreSameOne(ppparkParking, mapKitParking)
            }
        }

        logger.debug("Removing duplicated MapKit parkings")
        let uniquedParkingsListedOnlyOnMapKit = parkingsListedOnlyOnMapKit.uniqued { (parkingA, parkingB) in
            assumesParkingsAreSameOne(parkingA, parkingB)
        } picking: { (duplications) in
            let picked = duplications.max { $0.detailLevel < $1.detailLevel }!
            logger.debug("Picking \(picked.name) from duplications: \(duplications.map { $0.name })")
            return picked
        }

        var parkings: [ParkingProtocol] = ppparkParkings
        parkings.append(contentsOf: Array(uniquedParkingsListedOnlyOnMapKit))
        return parkings
    }

    private func assumesParkingsAreSameOne(_ parkingA: ParkingProtocol, _ parkingB: ParkingProtocol) -> Bool {
        let distance = parkingA.coordinate.distance(from: parkingB.coordinate)

        // Not close
        if distance > 30 {
            return false
        }

        logger.debug("Comparing \(parkingA.name), \(parkingB.name)")
        logger.debug("  Distance: \(distance)m")

            // Pretty close
        if distance <= 5 {
            logger.debug("    Same (pretty close)")
            return true
        }

        if parkingA.nameFeature.isEmpty || parkingB.nameFeature.isEmpty {
            logger.debug("    Same (either parking has no name)")
            return true
        }

        logger.debug("  Numbers in names: \(parkingA.numbersInName), \(parkingB.numbersInName))")

        // "第1駐車場" and "第2駐車場" must be different even if their name similarity is high
        if parkingA.numbersInName != parkingB.numbersInName {
            logger.debug("    Different (different numbers in names)")
            return false
        }

        // Relatively close and the names are similar
        let nameSimilarity = parkingA.nameFeature.similarity(to: parkingB.nameFeature)
        logger.debug("  Name similarity: \(nameSimilarity) (\(parkingA.nameFeature), \(parkingB.nameFeature))")

        if nameSimilarity >= 0.7 {
            logger.debug("    Same (name similarity >= 0.7)")
            return true
        } else {
            logger.debug("    Different (name similarity < 0.7)")
            return false
        }
    }
}

fileprivate extension Collection where Element: Hashable {
    func uniqued(with isDuplication: (Element, Element) -> Bool, picking picker: (Set<Element>) -> Element) -> Set<Element> {
        var remainingElements = Set(self)
        var uniquedElements = Set<Element>()

        while !remainingElements.isEmpty {
            let targetElement = remainingElements.removeFirst()

            let duplications = remainingElements.filter { (element) in
                isDuplication(element, targetElement)
            }

            if duplications.isEmpty {
                uniquedElements.insert(targetElement)
                continue
            }

            let allDuplications = duplications.union([targetElement])

            let elementToKeep = picker(allDuplications)
            uniquedElements.insert(elementToKeep)

            let elementsToRemove = allDuplications.subtracting([elementToKeep])
            remainingElements.subtract(elementsToRemove)
        }

        return uniquedElements
    }
}
