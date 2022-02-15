//
//  AccelerationHistory.swift
//  Dash
//
//  Created by Yuji Nakayama on 2022/02/15.
//  Copyright © 2022 Yuji Nakayama. All rights reserved.
//

import Foundation
import CoreMotion
import simd

actor AccelerationHistory {
    let expirationTimeInterval: TimeInterval
    let peakAngleResolution: Int

    private var accelerationsByAngleIndex: [Int: [Acceleration]] = [:]

    init(expirationTimeInterval: TimeInterval, peakAngleResolution: Int) {
        self.expirationTimeInterval = expirationTimeInterval
        self.peakAngleResolution = peakAngleResolution
    }

    func append(_ cmAcceleration: CMAcceleration) {
        let acceleration = Acceleration(acceleration: cmAcceleration, time: Date())
        let angleIndex = angleIndex(for: acceleration.twoDimentionalAngle)

        var accelerations = accelerationsByAngleIndex[angleIndex] ?? []
        accelerations.append(acceleration)
        accelerations.sort { $0.twoDimentionalLength < $1.twoDimentionalLength }
        accelerationsByAngleIndex[angleIndex] = accelerations
    }

    var currentPeaks: [Acceleration?] {
        removeExpiredAccelerations()

        var peaks: [Acceleration?] = []
        peaks.reserveCapacity(peakAngleResolution)

        for index in 0..<peakAngleResolution {
            let accelerations = accelerationsByAngleIndex[index]
            let peak = accelerations?.max(by: { $0.twoDimentionalLength < $1.twoDimentionalLength })
            peaks.append(peak)
        }

        return peaks
    }

    private func angleIndex(for angle: Angle) -> Int {
        let unitAngle = Angle(radians: .pi * 2 / Double(peakAngleResolution))

        for index in 0..<peakAngleResolution {
            let range = (unitAngle * index)..<(unitAngle * (index + 1))

            if range.contains(angle) {
                return index
            }
        }

        fatalError()
    }

    private func removeExpiredAccelerations() {
        let currentTime = Date()

        accelerationsByAngleIndex.forEach { (index, accelerations) in
            var accelerations = accelerations

            let firstValidIndex = accelerations.firstIndex { $0.time.distance(to: currentTime) < expirationTimeInterval }

            if let elementCountToRemove = firstValidIndex {
                accelerations.removeFirst(elementCountToRemove)
            } else {
                accelerations.removeAll()
            }

            accelerationsByAngleIndex[index] = accelerations
        }
    }
}

extension AccelerationHistory {
    struct Angle: Comparable, Hashable {
        static let zero = Angle(radians: 0)
        static let max = Angle(radians: .pi * 2)

        static func == (lhs: Angle, rhs: Angle) -> Bool {
            return lhs.radians == rhs.radians
        }

        static func < (lhs: Angle, rhs: Angle) -> Bool {
            return lhs.radians < rhs.radians
        }

        static func + (left: Angle, right: Angle) -> Angle {
            return Angle(radians: left.radians + right.radians)
        }

        static func * (left: Angle, right: Int) -> Angle {
            return Angle(radians: left.radians * Double(right))
        }

        var radians: Double

        init(radians: Double) {
            self.radians = radians
        }

        init(degrees: Double) {
            self.init(radians: degrees / 360 * .pi * 2)
        }

        init(acceleration: CMAcceleration) {
            let radians = atan2(acceleration.x, acceleration.y)

            if radians >= 0 {
                self.init(radians: radians)
            } else {
                self.init(radians: .pi * 2 + radians)
            }
        }
    }
}

extension AccelerationHistory {
    class Acceleration: Equatable {
        let acceleration: CMAcceleration
        let time: Date

        static func == (left: Acceleration, right: Acceleration) -> Bool {
            return left.acceleration == right.acceleration && left.time == right.time
        }

        init(acceleration: CMAcceleration, time: Date) {
            self.acceleration = acceleration
            self.time = time
        }

        lazy var twoDimentionalAngle: Angle = {
            return Angle(acceleration: acceleration)
        }()

        lazy var twoDimentionalLength: Double = {
            let vector = SIMD2<Double>(x: acceleration.x, y: acceleration.y)
            return simd_length(vector)
        }()
    }
}

extension CMAcceleration: Equatable {
    public static func == (left: CMAcceleration, right: CMAcceleration) -> Bool {
        return left.x == right.x && left.y == right.y && left.z == right.z
    }
}
