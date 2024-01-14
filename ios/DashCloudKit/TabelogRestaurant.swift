//
//  TabelogRestaurant.swift
//  DashCloudKit
//
//  Created by Yuji Nakayama on 2021/07/12.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import Foundation
import CoreLocation

public struct TabelogRestaurant: Decodable {
    public var address: String
    public var averageBudget: Budget
    public var coordinate: CLLocationCoordinate2D
    public var genres: [String]
    public var id: UInt
    public var name: String
    public var reviewCount: UInt
    public var score: Float
    public var webURL: URL
}

extension TabelogRestaurant {
    public struct Budget: Decodable {
      public var lunch: String
      public var dinner: String
    }
}
