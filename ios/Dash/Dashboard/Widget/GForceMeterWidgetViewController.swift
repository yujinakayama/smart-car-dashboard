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

    let accelerometer = Accelerometer()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addInteraction(UIContextMenuInteraction(delegate: self))

        if let referenceAcceleration = Defaults.shared.referenceAccelerationForGForceMeter {
            calibrationMatrix = makeCalibrationMatrix(from: referenceAcceleration)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startMetering()
    }

    override func viewDidDisappear(_ animated: Bool) {
        stopMetering()
        super.viewDidDisappear(animated)
    }

    func startMetering() {
        logger.info()

        accelerometer.startMetering() { [unowned self] (result) in
            switch result {
            case .success(let acceleration):
                self.displayCalibratedAcceleration(acceleration)
            case .failure(let error):
                logger.error(error)
            }
        }
    }

    func stopMetering() {
        logger.info()
        accelerometer.stopMetering()
    }

    private func displayCalibratedAcceleration(_ acceleration: CMAcceleration) {
        if calibrationMatrix == nil {
            setCurrentAccelerationAsReference()
        }

        if let calibrationMatrix = calibrationMatrix {
            gForceMeterView.acceleration = calibrate(acceleration, with: calibrationMatrix)
        }
    }

    private func setCurrentAccelerationAsReference() {
        guard let acceleration = accelerometer.acceleration else { return }
        Defaults.shared.referenceAccelerationForGForceMeter = acceleration
        calibrationMatrix = makeCalibrationMatrix(from: acceleration)
    }

    private var calibrationMatrix: simd_double3x3?

    func calibrate(_ acceleration: CMAcceleration, with calibrationMatrix: simd_double3x3) -> CMAcceleration {
        let vector = simd_double3(acceleration)
        let calibatedVector = calibrationMatrix * vector
        return CMAcceleration(calibatedVector)
    }

    private func makeCalibrationMatrix(from referenceAcceleration: CMAcceleration) -> simd_double3x3 {
        let referenceVector = simd_double3(referenceAcceleration)
        return makeMatrix(rotating: referenceVector, to: gravityVectorWithFaceUpDeviceOrientation)
    }

    // https://developer.apple.com/documentation/coremotion/getting_raw_accelerometer_events
    private let gravityVectorWithFaceUpDeviceOrientation = simd_double3(0, 0, -1)

    // https://math.stackexchange.com/a/476311
    private func makeMatrix(rotating sourceVector: simd_double3, to destinationVector: simd_double3) -> simd_double3x3 {
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

extension GForceMeterWidgetViewController: UIContextMenuInteractionDelegate {
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        let actionProvider: UIContextMenuActionProvider = { (suggestedActions) in
            let action = UIAction(title: "Calibrate Acceleration", image: UIImage(systemName: "gyroscope")) { (action) in
                // Delay to avoid vibrations by the touch operation
                Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] (timer) in
                    self?.setCurrentAccelerationAsReference()
                }
            }

            return UIMenu(title: "", children: [action])
        }

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil, actionProvider: actionProvider)
    }
}

class Accelerometer {
    lazy var motionManager: CMMotionManager = {
        let motionManager = CMMotionManager()
        motionManager.accelerometerUpdateInterval = 1 / 30
        return motionManager
    }()

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

    func startMetering(handler: @escaping (Result<CMAcceleration, Error>) -> Void) {
        guard !isMetering else { return }

        motionManager.startAccelerometerUpdates(to: .main) { [unowned self] (accelerometerData, error) in
            if let error = error {
                handler(.failure(error))
                return
            }

            if let acceleration = accelerometerData?.acceleration {
                let normalizedAcceleration = self.normalizeAccelerationBasedOnInterfaceOrientation(acceleration)
                handler(.success(normalizedAcceleration))
            } else {
                fatalError()
            }
        }
    }

    func stopMetering() {
        motionManager.stopAccelerometerUpdates()
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

    var interfaceOrientation: UIInterfaceOrientation {
        let scene = UIApplication.shared.connectedScenes.first as! UIWindowScene
        return scene.interfaceOrientation
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
        let sideLength = sqrt(scaleFrame.size.width) * 1.2
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
