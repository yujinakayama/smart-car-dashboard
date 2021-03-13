//
//  FilterableVideoDisplayView.swift
//  RearviewKit
//
//  Created by Yuji Nakayama on 2021/03/06.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import UIKit
import CoreMedia

class FilterableVideoDisplayView: CIImageDisplayView, VideoDisplayViewProtocol {
    typealias FilterName = String
    typealias FilterParameters = [String: Any]

    var filters: [FilterName: FilterParameters] = [:]

    private let decodingAndFilteringQueue = DispatchQueue(label: "FilterableVideoDisplayView (decoding and filtering)")

    private var decoder: SampleBufferDecoder?

    private var shouldDisplayImage = false

    func enqueue(_ sampleBuffer: CMSampleBuffer) {
        shouldDisplayImage = true

        if decoder == nil {
            decoder = SampleBufferDecoder()
        }

        guard let decoder = decoder else { abort() }

        decodingAndFilteringQueue.async {
            decoder.decode(sampleBuffer) { [weak self] (image) in
                guard let self = self, let image = image else { return }
                let filteredImage = self.applyFilters(image)

                DispatchQueue.main.async {
                    self.image = filteredImage
                }
            }
        }
    }

    func flushAndRemoveImage() {
        shouldDisplayImage = false
        image = nil
    }

    private func applyFilters(_ inputImage: CIImage) -> CIImage {
        var image = inputImage

        for (filterName, parameters) in filters {
            image = image.applyingFilter(filterName, parameters: parameters)
        }

        return image
    }
}
