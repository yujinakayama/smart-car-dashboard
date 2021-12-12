//
//  Location.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/02/01.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import Foundation
import MapKit
import FirebaseFirestore
import CommonCrypto
import ParkingSearchKit

class Location: SharedItemProtocol {
    var firebaseDocument: DocumentReference?
    var identifier: String!

    let address: Address
    let categories: [Category]
    let coordinate: CLLocationCoordinate2D
    let name: String?
    let url: URL
    let websiteURL: URL?
    let creationDate: Date?
    var hasBeenOpened: Bool

    lazy var formattedAddress = address.format()

    lazy var pointOfInterestFinder: PointOfInterestFinder? = {
        guard let name = name else { return nil }
        return PointOfInterestFinder(name: name, coordinate: coordinate, maxDistance: 50)
    }()

    var title: String? {
        return name
    }

    func open(from viewController: UIViewController) {
        openDirectionsInMaps()
    }

    func openDirectionsInMaps() {
        if Defaults.shared.snapLocationToPointOfInterest {
            findCorrespondingPointOfInterest { [weak self] (pointOfInterestMapItem) in
                guard let self = self else { return }
                let mapItem = pointOfInterestMapItem ?? self.mapItem
                self.openDirectionsInMaps(to: mapItem)
            }
        } else {
            openDirectionsInMaps(to: mapItem)
        }
    }

    private func openDirectionsInMaps(to mapItem: MKMapItem) {
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }

    private func findCorrespondingPointOfInterest(completionHandler: @escaping (MKMapItem?) -> Void) {
        guard let pointOfInterestFinder = pointOfInterestFinder else {
            completionHandler(nil)
            return
        }

        pointOfInterestFinder.find(completionHandler: completionHandler)
    }

    var mapItem: MKMapItem {
        let placemark = MKPlacemark(coordinate: coordinate)

        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = name
        return mapItem
    }

    var googleMapsDirectionsURL: URL {
        // https://developers.google.com/maps/documentation/urls/get-started#directions-action
        var components = URLComponents(string: "https://www.google.com/maps/dir/?api=1")!
        components.queryItems?.append(URLQueryItem(name: "destination", value: "\(coordinate.latitude),\(coordinate.longitude)"))
        components.queryItems?.append(URLQueryItem(name: "travelmode", value: "driving"))
        return components.url!
    }

    var yahooCarNaviURL: URL {
        // https://note.com/yahoo_carnavi/n/n1d6b819a816c
        var components = URLComponents(string: "yjcarnavi://navi/select")!

        components.queryItems = [
            URLQueryItem(name: "lat", value: "\(coordinate.latitude)"),
            URLQueryItem(name: "lon", value: "\(coordinate.longitude)"),
            URLQueryItem(name: "name", value: name)
        ]

        return components.url!
    }

    class PointOfInterestFinder {
        static let cache = Cache(name: "PointOfInterestFinder", ageLimit: 60 * 60 * 24 * 7) // 7 days

        let name: String
        let coordinate: CLLocationCoordinate2D
        let maxDistance: CLLocationDistance

        private (set) var cachedMapItem: MKMapItem? {
            get {
                return PointOfInterestFinder.cache.object(forKey: cacheKey) as? MKMapItem
            }

            set {
                PointOfInterestFinder.cache.setObjectAsync(newValue, forKey: cacheKey)
            }
        }

        var isCached: Bool {
            PointOfInterestFinder.cache.containsObject(forKey: cacheKey)
        }

        private lazy var cacheKey: String = {
            let key = String(format: "%@|%f,%f|%f", name, coordinate.latitude, coordinate.longitude, maxDistance)
            return Cache.digestString(of: key)
        }()

        init(name: String, coordinate: CLLocationCoordinate2D, maxDistance: CLLocationDistance) {
            self.name = name
            self.coordinate = coordinate
            self.maxDistance = maxDistance
        }

        func find(completionHandler: @escaping (MKMapItem?) -> Void) {
            if isCached {
                completionHandler(cachedMapItem)
                return
            }

            MKLocalSearch(request: request).start { [weak self] (response, error) in
                guard let self = self else { return }

                guard error == nil else {
                    completionHandler(nil)
                    return
                }

                var foundMapItem: MKMapItem?

                if let mapItem = response?.mapItems.first, self.isClose(mapItem) {
                    foundMapItem = mapItem
                }

                self.cachedMapItem = foundMapItem
                completionHandler(foundMapItem)
            }
        }

        private var request: MKLocalSearch.Request {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = name
            request.region = MKCoordinateRegion(center: coordinate, latitudinalMeters: maxDistance, longitudinalMeters: maxDistance)
            return request
        }

        private func isClose(_ mapItem: MKMapItem) -> Bool {
            guard let pointOfInterestLocation = mapItem.placemark.location else {
                return false
            }

            return pointOfInterestLocation.distance(from: location) <= maxDistance
        }

        private var location: CLLocation {
            return CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        }
    }
}

extension Location {
    struct Address: Decodable {
        let country: String?
        let prefecture: String?
        let distinct: String?
        let locality: String?
        let subLocality: String?
        let houseNumber: String?

        func format() -> String? {
            let components = [
                prefecture,
                distinct,
                locality,
                subLocality,
                houseNumber
            ].compactMap { $0 }

            guard !components.isEmpty else { return nil }

            return components.reduce(into: [] as [String]) { (components, currentComponent) in
                guard let previousComponent = components.last else {
                    components.append(currentComponent)
                    return
                }

                if previousComponent.last?.isNumber ?? false && currentComponent.first?.isNumber ?? false {
                    components.append("-")
                } else {
                    components.append(" ")
                }

                components.append(currentComponent)
            }.joined()
        }
    }
}

extension Location {
    enum Category: String, Decodable {
        // https://developers.google.com/maps/documentation/places/web-service/supported_types
        case accounting
        case airport
        case amusementPark
        case aquarium
        case artGallery
        case atm
        case bakery
        case bank
        case bar
        case beautySalon
        case bicycleStore
        case bookStore
        case bowlingAlley
        case busStation
        case cafe
        case campground
        case carDealer
        case carRental
        case carRepair
        case carWash
        case casino
        case cemetery
        case church
        case cityHall
        case clothingStore
        case convenienceStore
        case courthouse
        case dentist
        case departmentStore
        case doctor
        case drugstore
        case electrician
        case electronicsStore
        case embassy
        case fireStation
        case florist
        case funeralHome
        case furnitureStore
        case gasStation
        case gym
        case hairCare
        case hardwareStore
        case hinduTemple
        case homeGoodsStore
        case hospital
        case insuranceAgency
        case jewelryStore
        case laundry
        case lawyer
        case library
        case lightRailStation
        case liquorStore
        case localGovernmentOffice
        case locksmith
        case lodging
        case mealDelivery
        case mealTakeaway
        case mosque
        case movieRental
        case movieTheater
        case movingCompany
        case museum
        case nightClub
        case painter
        case park
        case parking
        case petStore
        case pharmacy
        case physiotherapist
        case plumber
        case police
        case postOffice
        case primarySchool
        case realEstateAgency
        case restaurant
        case roofingContractor
        case rvPark
        case school
        case secondarySchool
        case shoeStore
        case shoppingMall
        case spa
        case stadium
        case storage
        case store
        case subwayStation
        case supermarket
        case synagogue
        case taxiStand
        case touristAttraction
        case trainStation
        case transitStation
        case travelAgency
        case university
        case veterinaryCare
        case zoo

        case administrativeAreaLevel1
        case administrativeAreaLevel2
        case administrativeAreaLevel3
        case administrativeAreaLevel4
        case administrativeAreaLevel5
        case archipelago
        case colloquialArea
        case continent
        case country
        case establishment
        case finance
        case floor
        case food
        case generalContractor
        case geocode
        case health
        case intersection
        case landmark
        case locality
        case naturalFeature
        case neighborhood
        case placeOfWorship
        case plusCode
        case pointOfInterest
        case political
        case postBox
        case postalCode
        case postalCodePrefix
        case postalCodeSuffix
        case postalTown
        case premise
        case room
        case route
        case streetAddress
        case streetNumber
        case sublocality
        case sublocalityLevel1
        case sublocalityLevel2
        case sublocalityLevel3
        case sublocalityLevel4
        case sublocalityLevel5
        case subpremise
        case townSquare

        // Deprecated Google Maps place types
        // https://stackoverflow.com/questions/43790991/new-type-for-the-deprecated-grocery-or-supermarket-type-in-google-places-api
        case groceryOrSupermarket

        // https://developer.apple.com/documentation/mapkit/mkpointofinterestcategory
//        case airport
//        case amusementPark
//        case aquarium
//        case atm
//        case bakery
//        case bank
        case beach
        case brewery
//        case cafe
//        case campground
//        case carRental
        case evCharger
//        case fireStation
        case fitnessCenter
        case foodMarket
//        case gasStation
//        case hospital
        case hotel
//        case laundry
//        case library
        case marina
//        case movieTheater
//        case museum
        case nationalPark
        case nightlife
//        case park
//        case parking
//        case pharmacy
//        case police
//        case postOffice
        case publicTransport
//        case restaurant
        case restroom
//        case school
//        case stadium
//        case store
        case theater
//        case university
        case winery
//        case zoo

        // Custom categories
        case buddhistTemple
        case shintoShrine

        case unknown

        init(from decoder: Decoder) throws {
            let rawValue = try decoder.singleValueContainer().decode(String.self)
            self = Self(rawValue: rawValue) ?? .unknown
        }
    }
}
