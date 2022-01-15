//
//  MapItem.swift
//  DashCloudKit
//
//  Created by Yuji Nakayama on 2022/01/15.
//  Copyright © 2022 Yuji Nakayama. All rights reserved.
//

import MapKit

// This is a work-around for a bug in MKMapItem
// where pointOfInterestCategory setter does not work
public struct MapItem {
    let mapItem: MKMapItem
    let customCategory: String

    public init(mapItem: MKMapItem, customCategory: String) {
        self.mapItem = mapItem
        self.customCategory = customCategory
    }
}
