//
//  AccelerationCalibrator.swift
//  Dash
//
//  Created by Yuji Nakayama on 2022/02/15.
//  Copyright © 2022 Yuji Nakayama. All rights reserved.
//

import Foundation
import CoreMotion
import simd

class AccelerationCalibrator {
    let calibrationMatrix: simd_double3x3

    init(referenceAcceleration: CMAcceleration) {
        self.calibrationMatrix = Self.makeCalibrationMatrix(from: referenceAcceleration)
    }

    func calibrate(_ acceleration: CMAcceleration) -> CMAcceleration {
        let vector = simd_double3(acceleration)
        let calibatedVector = calibrationMatrix * vector
        return CMAcceleration(calibatedVector)
    }

    private static func makeCalibrationMatrix(from referenceAcceleration: CMAcceleration) -> simd_double3x3 {
        let referenceVector = simd_double3(referenceAcceleration)
        return makeMatrix(rotating: referenceVector, to: gravityVectorWithFaceUpDeviceOrientation)
    }

    // https://developer.apple.com/documentation/coremotion/getting_raw_accelerometer_events
    private static let gravityVectorWithFaceUpDeviceOrientation = simd_double3(0, 0, -1)

    // https://math.stackexchange.com/a/476311
    private static func makeMatrix(rotating sourceVector: simd_double3, to destinationVector: simd_double3) -> simd_double3x3 {
        let v = cross(sourceVector, destinationVector)
        let s = simd_length(v)
        let c = dot(sourceVector, destinationVector)

        let vx = simd_matrix_from_rows(
            SIMD3(0, -v[2], v[1]),
            SIMD3(v[2], 0, -v[0]),
            SIMD3(-v[1], v[0], 0)
        )

        let r = matrix_identity_double3x3 + vx + vx * vx * Double((1 - c) / pow(s, 2))

        return r
    }
}
