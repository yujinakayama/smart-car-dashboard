//
//  AVSampleBufferDisplayView.swift
//  Rearview
//
//  Created by Yuji Nakayama on 2020/09/13.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit
import AVFoundation

// We use this simple custom view to easily handle change of layer frame
// https://marcosantadev.com/calayer-auto-layout-swift/
class AVSampleBufferDisplayView: UIView, VideoDisplayViewProtocol {
    var scalingMode: VideoDisplayViewScalingMode = .aspectFit {
        didSet {
            applyScalingMode()
        }
    }

    func enqueue(_ sampleBuffer: CMSampleBuffer) {
        displayLayer.enqueue(sampleBuffer)
    }

    func flushAndRemoveImage() {
        displayLayer.flushAndRemoveImage()
    }

    private func applyScalingMode() {
        switch scalingMode {
        case .aspectFit:
            displayLayer.videoGravity = .resize
        case .aspectFill:
            displayLayer.videoGravity = .resizeAspectFill
        }
    }

    override class var layerClass: AnyClass {
        return AVSampleBufferDisplayLayer.self
    }

    private var displayLayer: AVSampleBufferDisplayLayer {
        return layer as! AVSampleBufferDisplayLayer
    }
}
