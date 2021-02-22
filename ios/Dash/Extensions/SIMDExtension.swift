//
//  SIMDExtension.swift
//  Dash
//
//  Created by Yuji Nakayama on 2021/02/22.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import Foundation
import CoreMotion
import simd

extension simd_double3 {
    init(_ acceleration: CMAcceleration) {
        self.init(acceleration.x, acceleration.y, acceleration.z)
    }
}

extension CMAcceleration {
    init(_ vector: simd_double3) {
        self.init(x: vector.x, y: vector.y, z: vector.z)
    }
}
