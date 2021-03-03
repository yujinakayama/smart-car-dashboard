//
//  VideoDisplayView.swift
//  RearviewKit
//
//  Created by Yuji Nakayama on 2021/03/07.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import UIKit
import CoreMedia

class VideoDisplayView: UIView {
    let sampleBufferDisplayView = AVSampleBufferDisplayView()
    let filterableVideoDisplayView = FilterableVideoDisplayView()

    lazy var subVideoDisplayViews: [VideoDisplayViewProtocol] = [sampleBufferDisplayView, filterableVideoDisplayView]

    var activeView: VideoDisplayViewProtocol

    var filters: [String: [String: Any]] {
        get {
            return filterableVideoDisplayView.filters
        }

        set {
            filterableVideoDisplayView.filters = newValue
            switchActiveView()
        }
    }

    override init(frame: CGRect) {
        activeView = sampleBufferDisplayView
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        activeView = sampleBufferDisplayView
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        for subview in subVideoDisplayViews {
            addSubview(subview)

            subview.translatesAutoresizingMaskIntoConstraints = false

            NSLayoutConstraint.activate([
                subview.topAnchor.constraint(equalTo: topAnchor),
                subview.bottomAnchor.constraint(equalTo: bottomAnchor),
                subview.leftAnchor.constraint(equalTo: leftAnchor),
                subview.rightAnchor.constraint(equalTo: rightAnchor),
            ])
        }

        switchActiveView()
    }

    private func switchActiveView() {
        var inactiveView: VideoDisplayViewProtocol!

        if filters.isEmpty {
            activeView = sampleBufferDisplayView
            inactiveView = filterableVideoDisplayView
        } else {
            activeView = filterableVideoDisplayView
            inactiveView = sampleBufferDisplayView
        }

        activeView.isHidden = false

        inactiveView.flushAndRemoveImage()
        inactiveView.isHidden = true
    }
}

extension VideoDisplayView: VideoDisplayViewProtocol {
    var scalingMode: VideoDisplayViewScalingMode {
        get {
            return activeView.scalingMode
        }

        set {
            subVideoDisplayViews.forEach { $0.scalingMode = newValue }
        }
    }

    func enqueue(_ sampleBuffer: CMSampleBuffer) {
        activeView.enqueue(sampleBuffer)
    }

    func flushAndRemoveImage() {
        activeView.flushAndRemoveImage()
    }
}
