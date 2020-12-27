//
//  CameraSensitivityAdjuster.swift
//  Rearview
//
//  Created by Yuji Nakayama on 2020/11/05.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit

class CameraOptionsAdjuster: NSObject, SunDelegate {
    let sun = Sun()

    override init() {
        super.init()
        sun.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(updateCameraOptionsForCurrentSunAppearance), name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    func sun(_ sun: Sun, didChangeAppearance appearance: Sun.Appearance) {
        updateCameraOptions(for: appearance)
    }

    @objc func updateCameraOptionsForCurrentSunAppearance() {
        guard let sunAppearance = sun.appearance else { return }
        updateCameraOptions(for: sunAppearance)
    }

    func updateCameraOptions(for sunAppearance: Sun.Appearance) {
        let cameraOptions = suitableCameraOptions(for: sunAppearance)
        updateCameraOptions(cameraOptions)
    }

    func updateCameraOptions(_ cameraOptions: CameraOptions) {
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

    var url: URL? {
        guard let raspberryPiAddress = Defaults.shared.raspberryPiAddress else { return nil }

        var urlComponents = URLComponents()
        urlComponents.scheme = "http"
        urlComponents.host = raspberryPiAddress
        urlComponents.port = 5002
        urlComponents.path = "/raspivid-options"
        return urlComponents.url
    }

    func suitableCameraOptions(for sunAppearance: Sun.Appearance) -> CameraOptions {
        switch sunAppearance {
        case .day:
            return .day
        case .night:
            return .night
        }
    }
}
