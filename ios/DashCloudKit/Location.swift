//
//  Location.swift
//  DashCloudKit
//
//  Created by Yuji Nakayama on 2021/07/12.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import Foundation
import CoreLocation

public struct Location: Decodable {
    public let address: Address
    public let coordinate: CLLocationCoordinate2D
    public let name: String?
    public let url: URL
    public let websiteURL: URL?
}

public struct Address: Decodable {
    public let country: String?
    public let prefecture: String?
    public let distinct: String?
    public let locality: String?
    public let subLocality: String?
    public let houseNumber: String?
}
