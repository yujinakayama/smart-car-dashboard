//
//  Accelerometer.swift
//  Dash
//
//  Created by Yuji Nakayama on 2022/02/15.
//  Copyright © 2022 Yuji Nakayama. All rights reserved.
//

import UIKit
import CoreMotion

class Accelerometer {
    let motionManager = CMMotionManager()

    var acceleration: CMAcceleration? {
        if let acceleration = motionManager.accelerometerData?.acceleration {
            return normalizeAccelerationBasedOnInterfaceOrientation(acceleration)
        } else {
            return nil
        }
    }

    var isMetering: Bool {
        return motionManager.isAccelerometerActive
    }

    let queue: OperationQueue
    let interfaceOrientation: UIInterfaceOrientation
    let currentValueRatioForSmoothing: Double?

    private var previousSmoothedAcceleration: CMAcceleration?

    init(updateInterval: TimeInterval, queue: OperationQueue, interfaceOrientation: UIInterfaceOrientation, currentValueRatioForSmoothing: Double?) {
        motionManager.accelerometerUpdateInterval = updateInterval
        self.queue = queue
        self.interfaceOrientation = interfaceOrientation
        self.currentValueRatioForSmoothing = currentValueRatioForSmoothing
    }

    func startMetering(handler: @escaping (Result<CMAcceleration, Error>) -> Void) {
        guard !isMetering else { return }

        motionManager.startAccelerometerUpdates(to: queue) { [weak self] (accelerometerData, error) in
            guard let self = self else { return }

            if let error = error {
                handler(.failure(error))
                return
            }

            if let acceleration = accelerometerData?.acceleration {
                let normalizedAcceleration = self.normalizeAccelerationBasedOnInterfaceOrientation(acceleration)
                let smoothedAcceleration = self.smooth(normalizedAcceleration)
                handler(.success(smoothedAcceleration))
            } else {
                fatalError()
            }
        }
    }

    func stopMetering() {
        motionManager.stopAccelerometerUpdates()
        previousSmoothedAcceleration = nil
    }

    private func normalizeAccelerationBasedOnInterfaceOrientation(_ acceleration: CMAcceleration) -> CMAcceleration {
        switch interfaceOrientation {
        case .portrait:
            return acceleration
        case .portraitUpsideDown:
            return CMAcceleration(x: -acceleration.x, y: -acceleration.y, z: acceleration.z)
        case .landscapeLeft:
            return CMAcceleration(x: acceleration.y, y: -acceleration.x, z: acceleration.z)
        case .landscapeRight:
            return CMAcceleration(x: -acceleration.y, y: acceleration.x, z: acceleration.z)
        default:
            return acceleration
        }
    }

    private func smooth(_ currentAcceleration: CMAcceleration) -> CMAcceleration {
        guard let currentValueRatio = currentValueRatioForSmoothing,
              currentValueRatio != 1,
              let previousSmoothedAcceleration = previousSmoothedAcceleration
        else {
            previousSmoothedAcceleration = currentAcceleration
            return currentAcceleration
        }

        let smoothedAcceleration = CMAcceleration(
            x: currentAcceleration.x * currentValueRatio + previousSmoothedAcceleration.x * (1 - currentValueRatio),
            y: currentAcceleration.y * currentValueRatio + previousSmoothedAcceleration.y * (1 - currentValueRatio),
            z: currentAcceleration.z * currentValueRatio + previousSmoothedAcceleration.z * (1 - currentValueRatio)
        )

        self.previousSmoothedAcceleration = smoothedAcceleration

        return smoothedAcceleration
    }
}
