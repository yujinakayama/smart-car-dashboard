//
//  Location.swift
//  DashCloudKit
//
//  Created by Yuji Nakayama on 2021/07/12.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import Foundation
import CoreLocation

public struct SearchResultWebpage: Decodable {
    public let title: String?
    public let link: URL
}
