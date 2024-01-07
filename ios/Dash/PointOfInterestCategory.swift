//
//  PointOfInterestCategory.swift
//  Dash
//
//  Created by Yuji Nakayama on 2022/02/03.
//  Copyright © 2022 Yuji Nakayama. All rights reserved.
//

import Foundation
import MapKit

enum PointOfInterestCategory: String {
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
    case rendezvous
    case restArea
    case roadsideStation

    case unknown
}

extension PointOfInterestCategory: Decodable {
    init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: rawValue) ?? .unknown
    }
}

extension PointOfInterestCategory {
    init?(_ mapKitPointOfInterestCategory: MKPointOfInterestCategory) {
        let normalizedValue = mapKitPointOfInterestCategory.rawValue
            .trimmingPrefix(/MKPOICategory/)
            .replacing(/^[A-Z]+(?![a-z])|^[A-Z][a-z]+/) { (firstWordMatch) in
                firstWordMatch.base.lowercased()
            }

        self.init(rawValue: String(normalizedValue))
    }

    var isKindOfParking: Bool {
        switch self {
        case .parking, .restArea, .roadsideStation:
            return true
        default:
            return false
        }
    }


    var isFoodProvider: Bool {
        switch self {
        case .bakery, .bar, .cafe, .food, .foodMarket, .mealDelivery, .mealTakeaway, .restaurant:
            return true
        default:
            return false
        }
    }

    var requiresAccurateCoordinate: Bool {
        switch self {
        case .parking, .rendezvous:
            return true
        default:
            return false
        }
    }
}
