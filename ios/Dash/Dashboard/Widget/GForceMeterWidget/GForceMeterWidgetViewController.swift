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

    let updateInterval: TimeInterval = 1 / 30

    var accelerometer: Accelerometer?
    let accelerometerQueue = OperationQueue()

    var calibrator: AccelerationCalibrator?

    var history: AccelerationHistory?

    var isVisible = false

    override func viewDidLoad() {
        super.viewDidLoad()

        previousInterfaceOrientation = currentInterfaceOrientation

        view.addInteraction(UIContextMenuInteraction(delegate: self))

        if let referenceAcceleration = Defaults.shared.referenceAccelerationForGForceMeter {
            calibrator = AccelerationCalibrator(referenceAcceleration: referenceAcceleration)
        }

        NotificationCenter.default.addObserver(self, selector: #selector(startIfNeeded), name: UIScene.willEnterForegroundNotification, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(stop), name: UIScene.didEnterBackgroundNotification, object: nil)

        // We want to observe notification for user interface orientation but there's no such one
        NotificationCenter.default.addObserver(self, selector: #selector(deviceOrientationDidChange), name: UIDevice.orientationDidChangeNotification, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        isVisible = true
        startIfNeeded()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        isVisible = false
        stop()
    }

    @objc func startIfNeeded() {
        guard accelerometer?.isMetering != true, isVisible else { return }

        logger.info()

        updateGForceMeterViewConfiguration()

        if Defaults.shared.showPeaksInGForceMeter {
            history = AccelerationHistory(
                expirationTimeInterval: Defaults.shared.peakExpirationDurationForGForceMeter,
                peakAngleResolution: Defaults.shared.peakAngleResolutionForGForceMeter
            )
        }

        let accelerometer = Accelerometer(
            updateInterval: updateInterval,
            queue: accelerometerQueue,
            interfaceOrientation: currentInterfaceOrientation,
            currentValueRatioForSmoothing: Defaults.shared.currentValueRatioForSmoothingInGForceMeter
        )

        accelerometer.startMetering() { [unowned self] (result) in
            switch result {
            case .success(let acceleration):
                Task {
                    await self.display(acceleration)
                }
            case .failure(let error):
                logger.error(error)
            }
        }

        self.accelerometer = accelerometer
    }

    @objc func stop() {
        logger.info()

        accelerometer?.stopMetering()
        accelerometer = nil
        history = nil

        gForceMeterView.acceleration = nil
        gForceMeterView.peaks = nil
    }

    private func updateGForceMeterViewConfiguration() {
        gForceMeterView.pointerAnimationDuration = updateInterval
        gForceMeterView.unitOfScale = Defaults.shared.unitOfGForceMeterScale
        gForceMeterView.pointerScalingBaseForVerticalAcceleration = Defaults.shared.pointerScalingBaseForVerticalAccelerationForGForceMeter
    }

    private func display(_ acceleration: CMAcceleration) async {
        if calibrator == nil {
            setCurrentAccelerationAsReference()
        }

        guard let calibrator = calibrator else { return }
        let calibratedAcceleration = calibrator.calibrate(acceleration)

        let peaks: [AccelerationHistory.Acceleration?]?

        if let history = history {
            await history.append(calibratedAcceleration)
            peaks = await history.currentPeaks
        } else {
            peaks = nil
        }

        await MainActor.run {
            gForceMeterView.acceleration = calibratedAcceleration

            if let peaks = peaks {
                gForceMeterView.peaks = peaks
            }
        }
    }

    private func setCurrentAccelerationAsReference() {
        guard let acceleration = accelerometer?.acceleration else { return }
        Defaults.shared.referenceAccelerationForGForceMeter = acceleration
        calibrator = AccelerationCalibrator(referenceAcceleration: acceleration)
    }

    @objc private func deviceOrientationDidChange() {
        if currentInterfaceOrientation == previousInterfaceOrientation { return }

        previousInterfaceOrientation = currentInterfaceOrientation

        if accelerometer?.isMetering == true {
            // Restart accelerometer to apply the new user interface orientation
            stop()
            startIfNeeded()
        }
    }

    private var currentInterfaceOrientation: UIInterfaceOrientation {
        let scene = UIApplication.shared.connectedScenes.first as! UIWindowScene
        return scene.interfaceOrientation
    }

    private var previousInterfaceOrientation: UIInterfaceOrientation!
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
