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

    func search() async throws -> [ParkingProtocol] {
        async let ppparkParkings = searchParkingsWithPPPark()
        async let mapKitParkings = searchParkingsWithMapKit()
        async let timesParkings = searchParkingsWithTimes()

        let aggregation = Aggregation(
            ppparkParkings: try await ppparkParkings,
            mapKitParkings: try await mapKitParkings,
            timesParkings: try await timesParkings
        )

        return aggregation.aggregatedParkings
    }

    private func searchParkingsWithPPPark() async throws -> [PPPark.Parking] {
        return try await pppark.searchParkings(around: destination, entranceDate: entranceDate, exitDate: exitDate)
    }

    private func searchParkingsWithMapKit() async throws -> [MapKitParking] {
        let parkingSearch = MapKitParkingSearch(destination: destination, entranceDate: entranceDate, exitDate: exitDate)
        return try await parkingSearch.search()
    }

    private func searchParkingsWithTimes() async throws -> [Times.Parking] {
        let region = MKCoordinateRegion(center: destination, latitudinalMeters: 1000, longitudinalMeters: 1000)
        return try await Times.searchParkings(within: region)
    }
}

extension ParkingSearch {
    class Aggregation {
        let ppparkParkings: [PPPark.Parking]
        let mapKitParkings: [MapKitParking]
        let timesParkings: [Times.Parking]

        init(ppparkParkings: [PPPark.Parking], mapKitParkings: [MapKitParking], timesParkings: [Times.Parking]) {
            self.ppparkParkings = ppparkParkings
            self.mapKitParkings = mapKitParkings
            self.timesParkings = timesParkings
        }

        lazy var aggregatedParkings: [ParkingProtocol] = {
            var parkings: [ParkingProtocol] = ppparkParkingsWithTimesAvailability
            parkings.append(contentsOf: Array(uniquedParkingsListedOnlyOnMapKit))
            return parkings
        }()

        private var ppparkParkingsWithTimesAvailability: [PPPark.Parking] {
            logger.verbose("Assigning PPPark parkings availability from corresponding Times parkings")

            return ppparkParkings.map { (ppparkParking) in
                if ppparkParking.availability != nil { return ppparkParking }

                var ppparkParking = ppparkParking

                let matchingTimesParking = timesParkings.first { (timesParking) in
                    considersParkingsAreSame(timesParking, ppparkParking)
                }

                if let matchingTimesParking = matchingTimesParking {
                    ppparkParking.availability = matchingTimesParking.availability
                }

                return ppparkParking
            }
        }

        private var uniquedParkingsListedOnlyOnMapKit: [MapKitParking] {
            logger.verbose("Removing duplicated MapKit parkings")

            let set = parkingsListedOnlyOnMapKit.uniqued { (parkingA, parkingB) in
                considersParkingsAreSame(parkingA, parkingB)
            } picking: { (duplications) in
                let picked = duplications.max { $0.detailLevel < $1.detailLevel }!
                logger.verbose("Picking \(picked.name) from duplications: \(duplications.map { $0.name })")
                return picked
            }

            return Array(set)
        }

        private var parkingsListedOnlyOnMapKit: [MapKitParking] {
            return mapKitParkings.filter { (mapKitParking) in
                !ppparkParkings.contains { (ppparkParking) in
                    considersParkingsAreSame(ppparkParking, mapKitParking)
                }
            }
        }

        private func considersParkingsAreSame(_ parkingA: ParkingProtocol, _ parkingB: ParkingProtocol) -> Bool {
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
