//
//  PointOfInterestAnnotation.swift
//  Dash
//
//  Created by Yuji Nakayama on 2022/02/03.
//  Copyright © 2022 Yuji Nakayama. All rights reserved.
//

import MapKit

protocol PointOfInterestAnnotation: MKAnnotation {
    var categories: [PointOfInterestCategory] { get }
}
