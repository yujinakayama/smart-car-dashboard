//
//  GForceMeterWidgetViewController.swift
//  Dash
//
//  Created by Yuji Nakayama on 2021/02/20.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import UIKit
import CoreMotion
import simd

class GForceMeterWidgetViewController: UIViewController {
    @IBOutlet weak var gForceMeterView: GForceMeterView!

    lazy var motionManager: CMMotionManager = {
        let motionManager = CMMotionManager()
        motionManager.accelerometerUpdateInterval = 1 / 30
        return motionManager
    }()

    var isMetering = false

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if !isMetering {
            startMetering()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        stopMetering()
        super.viewDidDisappear(animated)
    }

    func startMetering() {
        logger.info()

        motionManager.startAccelerometerUpdates(to: .main) { [unowned self] (accelerometerData, error) in
            guard let acceleration = accelerometerData?.acceleration else { return }
            // TODO: calibarate the acceleration against stable acceleration
            self.gForceMeterView.acceleration = acceleration
        }

        isMetering = true
    }

    func stopMetering() {
        logger.info()
        motionManager.stopAccelerometerUpdates()
        isMetering = false
    }
}

@IBDesignable class GForceMeterView: UIView {
    let gForceForScale: CGFloat = 0.5

    var acceleration: CMAcceleration? {
        didSet {
            accelerationPointerLayer.isHidden = acceleration == nil
            updateAccelerationPointerPosition()
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

    override var bounds: CGRect {
        didSet {
            updateScaleShape()
            updateAccelerationPointerSize()
            updateAccelerationPointerPosition()
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

        updateScaleShape()
        layer.addSublayer(scaleLayer)

        updateAccelerationPointerSize()

        updateAccelerationPointerPosition()
        layer.addSublayer(accelerationPointerLayer)
    }

    private func updateColors() {
        scaleLayer.strokeColor = scaleColor.cgColor
        accelerationPointerLayer.fillColor = tintColor.cgColor
    }

    private func updateAccelerationPointerSize() {
        let sideLength = scaleFrame.size.width / 12
        let size = CGSize(width: sideLength, height: sideLength)
        accelerationPointerLayer.bounds = CGRect(origin: .zero, size: size)

        accelerationPointerLayer.path = UIBezierPath(ovalIn: accelerationPointerLayer.bounds).cgPath
    }

    private func updateAccelerationPointerPosition() {
        let scale = scaleLayer.frame

        accelerationPointerLayer.position = CGPoint(
            x: scale.midX + (CGFloat(acceleration?.x ?? 0) * CGFloat(scale.size.width / 2.0) / gForceForScale),
            y: scale.midY - (CGFloat(acceleration?.y ?? 0) * CGFloat(scale.size.height / 2.0) / gForceForScale)
        )
    }

    private lazy var accelerationPointerLayer: CAShapeLayer = {
        let shapeLayer = CAShapeLayer()
        shapeLayer.isHidden = true
        return shapeLayer
    }()

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
        let safeFrame = layer.bounds.inset(by: safeAreaInsets)
        let sideLength = min(safeFrame.size.width, safeFrame.size.height)
        return CGRect(
            x: safeFrame.midX - (sideLength / 2),
            y: safeFrame.midY - (sideLength / 2),
            width: sideLength,
            height: sideLength
        )
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        updateScaleShape()
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
