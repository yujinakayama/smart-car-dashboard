//
//  GForceMeterView.swift
//  Dash
//
//  Created by Yuji Nakayama on 2022/02/15.
//  Copyright © 2022 Yuji Nakayama. All rights reserved.
//

import UIKit
import CoreMotion

@IBDesignable class GForceMeterView: UIView {
    var unitOfScale: CGFloat {
        get {
            return meterView.unitOfScale
        }

        set {
            meterView.unitOfScale = newValue
        }
    }

    var pointerAnimationDuration: TimeInterval? {
        get {
            meterView.pointerAnimationDuration
        }

        set {
            meterView.pointerAnimationDuration = newValue
        }
    }

    var pointerScalingBaseForVerticalAcceleration: CGFloat? {
        get {
            return meterView.pointerScalingBaseForVerticalAcceleration
        }

        set {
            meterView.pointerScalingBaseForVerticalAcceleration = newValue
        }
    }

    var acceleration: CMAcceleration? {
        didSet {
            meterView.acceleration = acceleration
            updateLabelTexts()
        }
    }

    var peaks: [AccelerationHistory.Acceleration?]? {
        get {
            return meterView.peaks
        }

        set {
            meterView.peaks = newValue
        }
    }

    private lazy var horizontalStackView: UIStackView = {
        let horizontalStackView = UIStackView(arrangedSubviews: [
            leftLabel,
            leftLabelMarginView,
            verticalStackView,
            rightLabelMarginView,
            rightLabel
        ])

        horizontalStackView.axis = .horizontal
        horizontalStackView.alignment = .center
        horizontalStackView.distribution = .equalSpacing
        return horizontalStackView
    }()

    private lazy var verticalStackView: UIStackView = {
        let verticalStackView = UIStackView(arrangedSubviews: [
            frontLabel,
            frontLabelMarginView,
            meterView,
            backLabelMarginView,
            backLabel
        ])

        verticalStackView.axis = .vertical
        verticalStackView.alignment = .center
        verticalStackView.distribution = .fill
        return verticalStackView
    }()

    private let meterView = MeterView()

    private let frontLabel = GForceMeterView.makeLabel(textAlignment: .center)
    private let backLabel = GForceMeterView.makeLabel(textAlignment: .center)
    private let leftLabel = GForceMeterView.makeLabel(textAlignment: .right)
    private let rightLabel = GForceMeterView.makeLabel(textAlignment: .left)

    private var labels: [UILabel] {
        return [
            frontLabel,
            backLabel,
            leftLabel,
            rightLabel
        ]
    }

    private static func makeLabel(textAlignment: NSTextAlignment) -> UILabel {
        let label = Label()
        label.textColor = .secondaryLabel
        label.textAlignment = textAlignment
        return label
    }

    private let frontLabelMarginView = UIView()
    private let backLabelMarginView = UIView()
    private let leftLabelMarginView = UIView()
    private let rightLabelMarginView = UIView()

    private var marginViews: [UIView] {
        return [
            frontLabelMarginView,
            backLabelMarginView,
            leftLabelMarginView,
            rightLabelMarginView
        ]
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        commonInit()
    }

    private func commonInit() {
        updateLabelTexts()

        addSubview(horizontalStackView)

        for view in ([horizontalStackView, verticalStackView, meterView] + labels + marginViews) {
            view.translatesAutoresizingMaskIntoConstraints = false
        }

        // Label sizes
        NSLayoutConstraint.activate(Array(labels.map { (label) in
            [
                label.widthAnchor.constraint(equalTo: heightAnchor, multiplier: 0.3),
                label.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.03, constant: 10),
            ]
        }.joined()))

        // Margins
        NSLayoutConstraint.activate(Array(marginViews.map { (marginView) in
            [
                marginView.widthAnchor.constraint(equalTo: heightAnchor, multiplier: 0.04),
                marginView.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.04, constant: -3),
            ]
        }.joined()))

        NSLayoutConstraint.activate([
            horizontalStackView.topAnchor.constraint(equalTo: topAnchor),
            horizontalStackView.bottomAnchor.constraint(equalTo: bottomAnchor),
            horizontalStackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            verticalStackView.heightAnchor.constraint(equalTo: horizontalStackView.heightAnchor),
            meterView.widthAnchor.constraint(equalTo: meterView.heightAnchor),
        ])
    }

    private func updateLabelTexts() {
        updateLabelTextsForAxis(
            value: acceleration?.x ?? 0,
            positiveLabel: rightLabel,
            negativeLabel: leftLabel
        )

        updateLabelTextsForAxis(
            value: acceleration?.y ?? 0,
            positiveLabel: frontLabel,
            negativeLabel: backLabel
        )
    }

    private func updateLabelTextsForAxis(value: Double, positiveLabel: UILabel, negativeLabel: UILabel) {
        let targetLabel: UILabel
        let nonTargetLabel: UILabel

        if value >= 0 {
            targetLabel = positiveLabel
            nonTargetLabel = negativeLabel
        } else {
            targetLabel = negativeLabel
            nonTargetLabel = positiveLabel
        }

        targetLabel.text = format(abs(value))
        nonTargetLabel.text = format(0)
    }

    private func format(_ value: Double) -> String {
        return String(format: "%.1f", value)
    }
}

extension GForceMeterView {
    @IBDesignable class MeterView: UIView {
        var unitOfScale: CGFloat = 0.5

        var pointerAnimationDuration: TimeInterval?

        var pointerScalingBaseForVerticalAcceleration: CGFloat? {
            didSet {
                if pointerScalingBaseForVerticalAcceleration == nil {
                    accelerationPointerLayer.setAffineTransform(.identity)
                }
            }
        }

        var acceleration: CMAcceleration? {
            didSet {
                CATransaction.begin()

                if let animationDuration = pointerAnimationDuration {
                    CATransaction.setAnimationDuration(animationDuration)
                } else {
                    CATransaction.setDisableActions(true)
                }

                accelerationPointerLayer.isHidden = acceleration == nil
                updateAccelerationPointerPosition()
                updateAccelerationPointerScale()

                CATransaction.commit()
            }
        }

        var peaks: [AccelerationHistory.Acceleration?]? {
            didSet {
                if peaks != oldValue {
                    updatePeakShape()
                }
            }
        }

        override var tintColor: UIColor! {
            didSet {
                updateColors()
            }
        }

        var scaleColor = UIColor.quaternaryLabel {
            didSet {
                updateColors()
            }
        }

        // This color should not have alpha because it causes different color line in rendered peak shape
        var peakFillColor = UIColor.systemGray5 {
            didSet {
                updateColors()
            }
        }

        override var bounds: CGRect {
            didSet {
                updateScaleShape()
                updateAccelerationPointerSize()
                updateAccelerationPointerPosition()
                updatePeakFrame()
                updatePeakLineWidth()
                updatePeakShape()
            }
        }

        override init(frame: CGRect) {
            super.init(frame: frame)
            commonInit()
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            commonInit()
        }

        override func prepareForInterfaceBuilder() {
            super.prepareForInterfaceBuilder()
            commonInit()
        }

        private func commonInit() {
            updateColors()

            updatePeakFrame()
            updatePeakLineWidth()
            layer.addSublayer(peakLayer)

            updateScaleShape()
            layer.addSublayer(scaleLayer)

            updateAccelerationPointerSize()
            updateAccelerationPointerPosition()
            layer.addSublayer(accelerationPointerLayer)
        }

        private func updateColors() {
            peakLayer.fillColor = peakFillColor.cgColor
            peakLayer.strokeColor = peakFillColor.cgColor
            scaleLayer.strokeColor = scaleColor.cgColor
            accelerationPointerLayer.fillColor = tintColor.cgColor
        }

        private func updateAccelerationPointerSize() {
            let sideLength = sqrt(scaleFrame.size.width) * 1.2
            let size = CGSize(width: sideLength, height: sideLength)
            accelerationPointerLayer.bounds = CGRect(origin: .zero, size: size)

            accelerationPointerLayer.path = UIBezierPath(ovalIn: accelerationPointerLayer.bounds).cgPath
        }

        private func updateAccelerationPointerPosition() {
            let scale = scaleLayer.frame

            accelerationPointerLayer.position = CGPoint(
                x: scale.midX + (CGFloat(acceleration?.x ?? 0) * CGFloat(scale.size.width / 2.0) / unitOfScale),
                y: scale.midY - (CGFloat(acceleration?.y ?? 0) * CGFloat(scale.size.height / 2.0) / unitOfScale)
            )
        }

        private func updateAccelerationPointerScale() {
            guard let pointerScalingBase = pointerScalingBaseForVerticalAcceleration else { return }

            // https://www.desmos.com/calculator/jcctj2ah0v
            let scale = pow(pointerScalingBase, CGFloat(acceleration?.z ?? -1) + 1)
            accelerationPointerLayer.setAffineTransform(CGAffineTransform(scaleX: scale, y: scale))
        }

        private lazy var accelerationPointerLayer: CAShapeLayer = {
            let shapeLayer = CAShapeLayer()
            shapeLayer.isHidden = true
            return shapeLayer
        }()

        private func updatePeakFrame() {
            peakLayer.frame = bounds
        }

        private func updatePeakLineWidth() {
            peakLayer.lineWidth = max(scaleFrame.width / 150, 1)
        }

        private func updatePeakShape() {
            peakLayer.path = peakPath()?.cgPath
        }

        private lazy var peakLayer: CAShapeLayer = {
            let shapeLayer = CAShapeLayer()
            shapeLayer.lineJoin = .round
            return shapeLayer
        }()

        private func peakPath() -> UIBezierPath? {
            guard let peaks = peaks else { return nil }

            let scale = scaleLayer.frame

            let path = UIBezierPath()

            for (index, peak) in peaks.enumerated() {
                let point: CGPoint

                if let peak = peak {
                    point = CGPoint(
                        x: scale.midX + (CGFloat(peak.acceleration.x) * CGFloat(scale.size.width / 2.0) / unitOfScale),
                        y: scale.midY - (CGFloat(peak.acceleration.y) * CGFloat(scale.size.height / 2.0) / unitOfScale)
                    )
                } else {
                    point = CGPoint(x: scale.midX, y: scale.midY)
                }


                if index == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }

            path.close()

            return path
        }

        private func updateScaleShape() {
            scaleLayer.frame = scaleFrame
            scaleLayer.path = scalePath(in: scaleLayer.bounds).cgPath
        }

        private lazy var scaleLayer: CAShapeLayer = {
            let shapeLayer = CAShapeLayer()
            shapeLayer.lineWidth = 1
            shapeLayer.fillColor = nil
            return shapeLayer
        }()

        private func scalePath(in bounds: CGRect) -> UIBezierPath {
            let path = UIBezierPath()
            path.append(crossPath(in: bounds))
            path.append(circlePath(in: bounds))
            return path
        }

        private func circlePath(in bounds: CGRect) -> UIBezierPath {
            return UIBezierPath(ovalIn: bounds)
        }

        private func crossPath(in bounds: CGRect) -> UIBezierPath {
            let path = UIBezierPath()

            let bounds = bounds

            // Horizontal line
            path.move(to: CGPoint(x: 0, y: bounds.midY))
            path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.midY))

            // Vertical line
            path.move(to: CGPoint(x: bounds.midX, y: 0))
            path.addLine(to: CGPoint(x: bounds.midX, y: bounds.maxY))

            return path
        }

        private var scaleFrame: CGRect {
            let sideLength = min(bounds.size.width, bounds.size.height)

            return CGRect(
                x: bounds.midX - (sideLength / 2),
                y: bounds.midY - (sideLength / 2),
                width: sideLength,
                height: sideLength
            )
        }

        override func tintColorDidChange() {
            super.tintColorDidChange()
            updateColors()
        }

        override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
            super.traitCollectionDidChange(previousTraitCollection)

            if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                updateColors()
            }
        }
    }
}

extension GForceMeterView {
    @IBDesignable class Label: UILabel {
        override var bounds: CGRect {
            didSet {
                font = UIFont.monospacedDigitSystemFont(ofSize: bounds.height, weight: .medium)
            }
        }
    }
}
