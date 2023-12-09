//
//  ProgressView.swift
//  CheckmarkView
//
//  Created by Yuji Nakayama on 2023/12/08.
//  Copyright © 2023 Yuji Nakayama. All rights reserved.
//

import UIKit

public class ProgressView: UIView {
    public override var bounds: CGRect {
        didSet {
            updateShape()
        }
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        updateShape()
        updateColor()
        layer.addSublayer(shapeLayer)
    }

    public func startAnimating() {
        RotationStarter(layer: shapeLayer).apply()
    }

    public func stopAnimating() {
        RotationEnder(layer: shapeLayer).apply()
    }

    public var isAnimating: Bool {
        return shapeLayer.animation(forKey: RotationStarter.animationKey) != nil
    }

    let shapeLayer: CAShapeLayer = {
        let shapeLayer = CAShapeLayer()
        shapeLayer.lineCap = .round
        shapeLayer.fillColor = nil
        return shapeLayer
    }()

    func updateShape() {
        shapeLayer.frame = drawingRegionSquareFrame // In view's coordinate system
        shapeLayer.path = makeCirclePath().cgPath
        shapeLayer.lineWidth = lineWidth
    }

    func updateColor() {
        shapeLayer.strokeColor = tintColor.resolvedColor(with: traitCollection).cgColor
    }

    func makeCirclePath() -> UIBezierPath {
        // In shapeLayer's coordinate system
        let circleFrame = shapeLayer.bounds.insetBy(dx: lineWidth / 2, dy: lineWidth / 2)

        return UIBezierPath(
            arcCenter: circleFrame.center,
            radius: circleFrame.size.width / 2,
            startAngle: 0.5 * .pi,
            endAngle: 2.5 * .pi,
            clockwise: true
        )
    }

    var drawingRegionSquareFrame: CGRect {
        return CGRect(
            x: (bounds.width - drawingRegionSideLength) / 2,
            y: (bounds.height - drawingRegionSideLength) / 2,
            width: drawingRegionSideLength,
            height: drawingRegionSideLength
        )
    }

    var drawingRegionSideLength: CGFloat {
        return min(bounds.width, bounds.height)
    }

    var lineWidth: CGFloat {
        return drawingRegionSideLength * 0.05
    }
    
    public override func tintColorDidChange() {
        super.tintColorDidChange()
        updateColor()
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateColor()
        }
    }
}

extension ProgressView {
    class RotationStarter {
        static let animationKey = "RotationStarter"

        let layer: CALayer

        init(layer: CALayer) {
            self.layer = layer
        }

        func apply() {
            layer.add(animation, forKey: Self.animationKey)
        }

        private lazy var animation = {
            let group = CAAnimationGroup()
            group.animations = [
                circleOpenAnimation,
                easeInRotationAnimation,
                infiniteRotationAnimation
            ]
            group.duration = .greatestFiniteMagnitude
            return group
        }()

        private let startUpDuration = 0.2

        private lazy var circleOpenAnimation = {
            let animation = CABasicAnimation(keyPath: "strokeStart")
            animation.fromValue = 0
            animation.toValue = 0.068
            animation.duration = startUpDuration
            animation.fillMode = .forwards
            animation.isRemovedOnCompletion = false
            animation.timingFunction = .init(name: .easeInEaseOut)
            return animation
        }()

        private lazy var easeInRotationAnimation = {
            let animation = CABasicAnimation(keyPath: "transform.rotation")
            animation.fromValue = 0
            animation.toValue = 15.0 / 180.0 * Float.pi
            animation.duration = startUpDuration
            animation.fillMode = .forwards
            animation.isRemovedOnCompletion = false
            animation.timingFunction = .init(name: .easeIn)
            return animation
        }()

        private lazy var infiniteRotationAnimation = {
            let animation = CABasicAnimation(keyPath: "transform.rotation")
            animation.byValue = Float.pi * 2
            animation.duration = 1
            animation.repeatCount = .greatestFiniteMagnitude
            animation.beginTime = startUpDuration
            return animation
        }()
    }
}

extension ProgressView {
    class RotationEnder: NSObject, CAAnimationDelegate {
        let layer: CALayer

        init(layer: CALayer) {
            self.layer = layer
        }

        func apply() {
            layer.add(circleCloseAnimation, forKey: nil)
        }

        func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
            layer.removeAnimation(forKey: RotationStarter.animationKey)
        }

        private lazy var circleCloseAnimation = {
            let animation = CABasicAnimation(keyPath: "strokeStart")
            animation.delegate = self
            animation.toValue = 0
            animation.duration = 0.2
            animation.fillMode = .forwards
            animation.isRemovedOnCompletion = false
            animation.timingFunction = .init(name: .easeInEaseOut)
            return animation
        }()
    }
}

fileprivate extension CGRect {
    var center: CGPoint {
        return CGPoint(x: midX, y: midY)
    }
}
