//
//  DirectionalUserLocationAnnotationView.swift
//  DirectionalUserLocationAnnotationView
//
//  Created by Yuji Nakayama on 2020/04/18.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import MapKit

// TODO: Change view size in accordance with map view's zoom level
class DirectionalUserLocationAnnotationView: MKAnnotationView {
    let symbolPointSize: CGFloat = 21

    let circleView = CircleView()
    let arrowView = ArrowView()

    var directionAnimationDuration: TimeInterval = 1

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        commonInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }

    func commonInit() {
        circleView.sizeToFit()
        addSubview(circleView)

        arrowView.sizeToFit()
        arrowView.center = circleView.center
        addSubview(arrowView)

        centerOffset = CGPoint(x: -circleView.center.x, y: -circleView.center.y)
    }

    override var annotation: MKAnnotation? {
        didSet {
            updateDirection(animated: false)
        }
    }

    func updateDirection(animated: Bool) {
        guard let directionInDegrees = direction else { return }

        let transform = CGAffineTransform(rotationAngle: CGFloat(directionInDegrees / 180.0 * Double.pi))

        if animated {
            UIView.animate(withDuration: directionAnimationDuration) {
                self.arrowView.transform = transform
            }
        } else {
            arrowView.transform = transform
        }
    }

    var direction: CLLocationDirection? {
        guard let userLocation = annotation as? MKUserLocation else { return nil }
        guard let location = userLocation.location, location.course >= 0 else { return nil }
        return location.course
    }

    class CircleView: UIView {
        let size = CGSize(width: 36, height: 36)
        let lineWidth: CGFloat = 2

        override init(frame: CGRect) {
            super.init(frame: frame)
            commonInit()
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            commonInit()
        }

        func commonInit() {
            isOpaque = false
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOffset = CGSize(width: 0, height: 1)
            layer.shadowRadius = 1
            layer.shadowOpacity = 0.17
        }

        override func draw(_ rect: CGRect) {
            let circle = UIBezierPath(
                arcCenter: CGPoint(x: bounds.midX, y: bounds.midY),
                radius: (bounds.size.width - lineWidth) / 2,
                startAngle: 0,
                endAngle: CGFloat(Double.pi) * 2,
                clockwise: true
            )

            UIColor.white.setFill()
            circle.fill()

            tintColor.setStroke()
            circle.lineWidth = lineWidth
            circle.stroke()
        }

        override func tintColorDidChange() {
            super.tintColorDidChange()
            setNeedsDisplay()
        }

        override func sizeThatFits(_ size: CGSize) -> CGSize {
            return self.size
        }
    }

    class ArrowView: UIView {
        override init(frame: CGRect) {
            super.init(frame: frame)
            commonInit()
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            commonInit()
        }

        func commonInit() {
            isOpaque = false
        }

        override func draw(_ rect: CGRect) {
            tintColor.setFill()
            path.fill()
        }

        lazy var path: UIBezierPath = {
            // Generated from arrow.svg with http://svg-converter.kyome.io
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 0.6, y: 21.2))
            path.addCurve(to: CGPoint(x: 1.1, y: 21), controlPoint1: CGPoint(x: 0.7, y: 21.2), controlPoint2: CGPoint(x: 0.9, y: 21.2))
            path.addLine(to: CGPoint(x: 7.9, y: 14.2))
            path.addCurve(to: CGPoint(x: 8, y: 14.1), controlPoint1: CGPoint(x: 7.9, y: 14.1), controlPoint2: CGPoint(x: 8, y: 14.1))
            path.addCurve(to: CGPoint(x: 8.1, y: 14.2), controlPoint1: CGPoint(x: 8, y: 14.1), controlPoint2: CGPoint(x: 8.1, y: 14.1))
            path.addLine(to: CGPoint(x: 14.9, y: 21))
            path.addCurve(to: CGPoint(x: 15.4, y: 21.2), controlPoint1: CGPoint(x: 15.1, y: 21.2), controlPoint2: CGPoint(x: 15.3, y: 21.2))
            path.addCurve(to: CGPoint(x: 16, y: 20.7), controlPoint1: CGPoint(x: 15.7, y: 21.2), controlPoint2: CGPoint(x: 16, y: 21))
            path.addCurve(to: CGPoint(x: 15.9, y: 20.3), controlPoint1: CGPoint(x: 16, y: 20.6), controlPoint2: CGPoint(x: 15.9, y: 20.5))
            path.addLine(to: CGPoint(x: 8.7, y: 1.5))
            path.addCurve(to: CGPoint(x: 8, y: 0.7), controlPoint1: CGPoint(x: 8.5, y: 1.2), controlPoint2: CGPoint(x: 8.3, y: 0.7))
            path.addCurve(to: CGPoint(x: 7.4, y: 1.5), controlPoint1: CGPoint(x: 7.7, y: 0.7), controlPoint2: CGPoint(x: 7.5, y: 1.2))
            path.addLine(to: CGPoint(x: 0.1, y: 20.3))
            path.addCurve(to: CGPoint(x: 0.1, y: 20.7), controlPoint1: CGPoint(x: 0.1, y: 20.5), controlPoint2: CGPoint(x: 0.1, y: 20.6))
            path.addCurve(to: CGPoint(x: 0.6, y: 21.2), controlPoint1: CGPoint(x: 0.1, y: 21), controlPoint2: CGPoint(x: 0.3, y: 21.2))
            path.close()
            return path
        }()

        override func tintColorDidChange() {
            super.tintColorDidChange()
            setNeedsDisplay()
        }

        override func sizeThatFits(_ size: CGSize) -> CGSize {
            var size = path.bounds.size
            size.height += 3 // Tweak gravity center
            return size
        }
    }
}
