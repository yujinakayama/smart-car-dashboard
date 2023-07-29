//
//  InboxLocationAnnotation.swift
//  Dash
//
//  Created by Yuji Nakayama on 2021/07/22.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import MapKit

class InboxLocationAnnotation: NSObject, PointOfInterestAnnotation {
    let inboxLocation: InboxLocation
    
    init(_ location: InboxLocation) {
        self.inboxLocation = location
        super.init()
    }
    
    var coordinate: CLLocationCoordinate2D {
        return inboxLocation.coordinate
    }
    
    var title: String? {
        return inboxLocation.name
    }
    
    var subtitle: String? {
        return nil
    }
    
    var location: Location {
        .full(inboxLocation)
    }
}
