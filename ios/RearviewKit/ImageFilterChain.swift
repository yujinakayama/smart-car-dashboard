//
//  ImageFilterChain.swift
//  RearviewKit
//
//  Created by Yuji Nakayama on 2021/03/31.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import Foundation
import CoreImage

class ImageFilterChain {
    typealias FilterName = String
    typealias FilterParameters = [String: Any]

    let filters: [FilterName: FilterParameters]

    init(filters: [FilterName: FilterParameters]) {
        self.filters = filters
    }

    func apply(to inputImage: CIImage) -> CIImage {
        var image = inputImage

        for (filterName, parameters) in filters {
            image = image.applyingFilter(filterName, parameters: parameters)
        }

        return image
    }
}
