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

    static let ratioOfShorterLineLengthToLongerLineLength: CGFloat = 0.422

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

        //         Stroke direction
        //              ---->
        // 0.00/1.00             0.25
        //          +-----------+
        //          |           |
        //          |           |
        //          |           |
        //          |           |
        //          +-----------+
        //      0.75             0.50
        shapeLayer.strokeEnd = 0.75 + (0.25 * Self.ratioOfShorterLineLengthToLongerLineLength)
        shapeLayer.strokeStart = 0.50

        shapeLayer.lineWidth = lineWidth
        shapeLayer.lineCap = .round

        shapeLayer.strokeColor = tintColor.cgColor
        shapeLayer.fillColor = nil

        return shapeLayer
    }

    func makeSquareStrokePath() -> UIBezierPath {
        // In shape layer's coordinate system
        let squareStrokeSideLength = (drawingRegionSideLength - lineWidth) * 0.98
        let squareOrigin = CGPoint(x: -squareStrokeSideLength * 0.5, y: -squareStrokeSideLength * 0.5)
        let squareSize = CGSize(width: squareStrokeSideLength, height: squareStrokeSideLength)

        let path = UIBezierPath(roundedRect: CGRect(origin: squareOrigin, size: squareSize), cornerRadius: 0.001)

        let fortyFiveDegreesCounterClockwise = CGFloat(-Double.pi / 4)
        path.apply(CGAffineTransform(rotationAngle: fortyFiveDegreesCounterClockwise))

        let movement = CGAffineTransform(
            translationX: (drawingRegionSideLength * 0.303) + (lineWidth * 0.191),
            y: (drawingRegionSideLength * 0.155) + (lineWidth * 0.325)
        )
        path.apply(movement)

        return path
    }

    func makeAnimation(for shapeLayer: CAShapeLayer, duration: TimeInterval) -> CAAnimation {
        let animation = CABasicAnimation(keyPath: "strokeStart")
        animation.fromValue = shapeLayer.strokeEnd
        animation.toValue = shapeLayer.strokeStart
        animation.duration = duration
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
        return drawingRegionSideLength * 0.11
    }
}

extension CheckmarkView {
    func showDebugGuides(for shapeLayer: CAShapeLayer) {
        // Entire view
        backgroundColor = UIColor.label.withAlphaComponent(0.05)

        // Drawing region
        shapeLayer.backgroundColor = UIColor.green.withAlphaComponent(0.2).cgColor
        layer.addSublayer(rulerLayer)

        // Square shape
        shapeLayer.fillColor = UIColor.blue.withAlphaComponent(0.2).cgColor

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
