//
//  CheckmarkView.swift
//  CheckmarkView
//
//  Created by Yuji Nakayama on 2020/02/08.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit

public class CheckmarkView: UIView {
    public static let defaultAnimationDuration: TimeInterval = 0.5

    public var showsDebugGuides = false

    public func startAnimating(duration: TimeInterval = CheckmarkView.defaultAnimationDuration) {
        shapeLayer?.removeFromSuperlayer()

        let shapeLayer = makeShapeLayer()
        layer.addSublayer(shapeLayer)

        let animation = makeAnimation(for: shapeLayer, duration: duration)
        shapeLayer.add(animation, forKey: nil)
        
        self.shapeLayer = shapeLayer
        
        if showsDebugGuides {
            showDebugGuides(for: shapeLayer)
        }
    }

    var shapeLayer: CAShapeLayer?

    func makeShapeLayer() -> CAShapeLayer {
        let shapeLayer = CAShapeLayer()

        // In view's coordinate system
        shapeLayer.frame = drawingRegionSquareFrame

        shapeLayer.path = makeSquareStrokePath().cgPath

        shapeLayer.lineWidth = lineWidth
        shapeLayer.lineCap = .round
        shapeLayer.lineJoin = .round

        shapeLayer.strokeColor = tintColor.resolvedColor(with: traitCollection).cgColor
        shapeLayer.fillColor = nil

        return shapeLayer
    }

    func makeSquareStrokePath() -> UIBezierPath {
        // In shape layer's coordinate system

        let sideLength = drawingRegionSideLength
        let lineHalfWidth = lineWidth / 2

        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0.01 * sideLength + lineHalfWidth, y: 0.525 * sideLength))
        path.addLine(to: CGPoint(x: 0.392 * sideLength, y: 0.98 * sideLength - lineHalfWidth))
        path.addLine(to: CGPoint(x: sideLength - lineHalfWidth, y: lineHalfWidth))
        return path
    }

    func makeAnimation(for shapeLayer: CAShapeLayer, duration: TimeInterval) -> CAAnimation {
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.fromValue = shapeLayer.strokeStart
        animation.toValue = shapeLayer.strokeEnd
        animation.duration = duration
        // https://cubic-bezier.com/#.5,0,0,1
        animation.timingFunction = CAMediaTimingFunction(controlPoints: 0.5, 0, 0, 1)
        return animation
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
        return drawingRegionSideLength * 0.132
    }
    
    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection),
           let shapeLayer = shapeLayer
        {
            shapeLayer.strokeColor = tintColor.resolvedColor(with: traitCollection).cgColor
        }
    }
}

extension CheckmarkView {
    func showDebugGuides(for shapeLayer: CAShapeLayer) {
        // Entire view
        backgroundColor = UIColor.label.withAlphaComponent(0.05)

        // Drawing region
        shapeLayer.backgroundColor = UIColor.green.withAlphaComponent(0.2).cgColor
        layer.addSublayer(rulerLayer)

        // Checkmark stroke
        shapeLayer.strokeColor = UIColor.red.withAlphaComponent(0.5).cgColor

        return
    }

    var rulerLayer: CALayer {
        let path = UIBezierPath()

        path.move(to: CGPoint(x: drawingRegionSideLength * 0.5, y: 0))
        path.addLine(to: CGPoint(x: drawingRegionSideLength * 0.5, y: drawingRegionSideLength))

        path.move(to: CGPoint(x: 0, y: drawingRegionSideLength * 0.5))
        path.addLine(to: CGPoint(x: drawingRegionSideLength, y: drawingRegionSideLength * 0.5))

        let shapeLayer = CAShapeLayer()
        shapeLayer.frame = drawingRegionSquareFrame // In view's bounds coordinate system
        shapeLayer.path = path.cgPath
        shapeLayer.lineWidth = 1
        shapeLayer.strokeColor = UIColor.label.withAlphaComponent(0.5).cgColor
        return shapeLayer
    }
}
