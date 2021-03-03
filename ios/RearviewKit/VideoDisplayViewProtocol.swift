//
//  VideoDisplayViewProtocol.swift
//  RearviewKit
//
//  Created by Yuji Nakayama on 2021/03/04.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import UIKit
import CoreMedia

protocol VideoDisplayViewProtocol: UIView {
    var scalingMode: VideoDisplayViewScalingMode { get set }

    func enqueue(_ sampleBuffer: CMSampleBuffer)
    func flushAndRemoveImage()
}

enum VideoDisplayViewScalingMode {
    case aspectFit
    case aspectFill
}
