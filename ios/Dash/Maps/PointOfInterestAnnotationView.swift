//
//  PointOfInterestAnnotationView.swift
//  Dash
//
//  Created by Yuji Nakayama on 2021/07/22.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import MapKit

class PointOfInterestAnnotationView: MKMarkerAnnotationView {
    override var annotation: MKAnnotation? {
        didSet {
            updateGlyph()
        }
    }

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        collisionMode = .none
        displayPriority = .required
        updateGlyph()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateGlyph() {
        guard let annotation = annotation as? PointOfInterestAnnotation else { return }
        let icon = PointOfInterestIcon(categories: annotation.categories)
        glyphImage = icon.image
        markerTintColor = icon.color
    }
}
