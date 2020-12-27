//
//  CameraSensitivityAdjuster.swift
//  Rearview
//
//  Created by Yuji Nakayama on 2020/11/05.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit

class CameraOptionsAdjuster: NSObject, SunDelegate {
    enum SensitivityMode: Int, CaseIterable {
        case auto = 0
        case day
        case night
        case lowLight
        case ultraLowLight
    }

    let sun = Sun()

    var sensitivityMode: SensitivityMode {
        get {
            return Defaults.shared.cameraSensitivityMode ?? .auto
        }

        set {
            Defaults.shared.cameraSensitivityMode = newValue
            applySensitivityMode()
        }
    }

    override init() {
        super.init()
        sun.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(applySensitivityMode), name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    @objc private func applySensitivityMode() {
        logger.info(sensitivityMode)

        var cameraOptions: CameraOptions?

        switch sensitivityMode {
        case .auto:
            updateCameraOptionsForCurrentSunAppearanceIfPossible()
            sun.startTrackingAppearance()
            return
        case .day:
            cameraOptions = CameraOptions.day
        case .night:
            cameraOptions = CameraOptions.night
        case .lowLight:
            cameraOptions = CameraOptions.fixedSensitivity(digitalgain: 6)
        case .ultraLowLight:
            cameraOptions = CameraOptions.fixedSensitivity(digitalgain: 10)
        }

        if let cameraOptions = cameraOptions {
            sun.stopTrackingAppearance()
            updateCameraOptions(cameraOptions)
        }
    }

    func sun(_ sun: Sun, didChangeAppearance appearance: Sun.Appearance) {
        updateCameraOptions(for: appearance)
    }

    @objc private func updateCameraOptionsForCurrentSunAppearanceIfPossible() {
        guard let sunAppearance = sun.appearance else { return }
        updateCameraOptions(for: sunAppearance)
    }

    private func updateCameraOptions(for sunAppearance: Sun.Appearance) {
        let cameraOptions = suitableCameraOptions(for: sunAppearance)
        updateCameraOptions(cameraOptions)
    }

    private func updateCameraOptions(_ cameraOptions: CameraOptions) {
        logger.info(cameraOptions)

        guard let url = url else {
            logger.error("Raspberry Pi address is not set")
            return
        }

        var request = URLRequest(url: url)
        request.allowsCellularAccess = false
        request.httpMethod = "PUT"

        do {
            request.httpBody = try JSONEncoder().encode(cameraOptions)
        } catch {
            logger.error(error)
            return
        }

        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                logger.error(error)
            } else {
                logger.info(response)
            }
        }

        task.resume()
    }

    private func suitableCameraOptions(for sunAppearance: Sun.Appearance) -> CameraOptions {
        switch sunAppearance {
        case .day:
            return .day
        case .night:
            return .night
        }
    }

    private var url: URL? {
        guard let raspberryPiAddress = Defaults.shared.raspberryPiAddress else { return nil }

        var urlComponents = URLComponents()
        urlComponents.scheme = "http"
        urlComponents.host = raspberryPiAddress
        urlComponents.port = 5002
        urlComponents.path = "/raspivid-options"
        return urlComponents.url
    }
}
