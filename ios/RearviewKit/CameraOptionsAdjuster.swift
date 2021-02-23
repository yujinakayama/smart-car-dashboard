//
//  CameraSensitivityAdjuster.swift
//  Rearview
//
//  Created by Yuji Nakayama on 2020/11/05.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit

class CameraOptionsAdjuster: NSObject, SunDelegate {
    let retryInterval: TimeInterval = 1

    var configuration: RearviewConfiguration

    let sun = Sun()

    var lastRequestError: Error?

    var remainingRetryCount = 0

    init(configuration: RearviewConfiguration) {
        self.configuration = configuration
        super.init()
        sun.delegate = self
    }

    func apply(_ sensitivityMode: CameraSensitivityMode, maxRetryCount: Int = 0) {
        logger.info(sensitivityMode)

        remainingRetryCount = maxRetryCount

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
            cameraOptions = CameraOptions.fixedSensitivity(digitalgain: configuration.digitalGainForLowLightMode)
        case .ultraLowLight:
            cameraOptions = CameraOptions.fixedSensitivity(digitalgain: configuration.digitalGainForUltraLowLightMode)
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

        let task = urlSession.dataTask(with: request) { (data, response, error) in
            self.lastRequestError = error

            if let error = error {
                logger.error(error)
                self.retryIfPossible(cameraOptions: cameraOptions)
            } else {
                logger.info(response)
            }
        }

        task.resume()
    }

    private func retryIfPossible(cameraOptions: CameraOptions) {
        logger.info("remainingRetryCount: \(remainingRetryCount)")

        guard remainingRetryCount > 0 else { return }

        remainingRetryCount -= 1

        DispatchQueue.global().asyncAfter(deadline: .now() + retryInterval) {
            self.updateCameraOptions(cameraOptions)
        }
    }

    private lazy var urlSession = URLSession(configuration: urlSessionConfiguration)

    private lazy var urlSessionConfiguration: URLSessionConfiguration = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.allowsCellularAccess = false
        configuration.timeoutIntervalForRequest = 1
        configuration.urlCache = nil
        return configuration
    }()

    private func suitableCameraOptions(for sunAppearance: Sun.Appearance) -> CameraOptions {
        switch sunAppearance {
        case .day:
            return .day
        case .night:
            return .night
        }
    }

    private var url: URL? {
        var urlComponents = URLComponents()
        urlComponents.scheme = "http"
        urlComponents.host = configuration.raspberryPiAddress.string
        urlComponents.port = 5002
        urlComponents.path = "/raspivid-options"
        return urlComponents.url
    }
}
