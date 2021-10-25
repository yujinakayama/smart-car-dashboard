//
//  RearviewManager.swift
//  Rearview
//
//  Created by Yuji Nakayama on 2021/10/25.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import UIKit
import RearviewKit

class RearviewManager: NSObject {
    var rearviewViewController: RearviewViewController?

    var isHandedOffFromOtherApp = false

    lazy var doubleTapGestureRecognizer: UITapGestureRecognizer = {
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(gestureRecognizerDidRecognizeDoubleTap))
        gestureRecognizer.numberOfTapsRequired = 2
        return gestureRecognizer
    }()

    func startIfPossible(window: UIWindow) {
        if let configuration = RearviewDefaults.shared.configuration {
            start(window: window, configuration: configuration)
        } else {
            showAlertAboutInvalidRaspberryPiAddress(window: window)
        }
    }

    func start(window: UIWindow, configuration: RearviewConfiguration) {
        let rearviewViewController = RearviewViewController(configuration: configuration, cameraSensitivityMode: RearviewDefaults.shared.cameraSensitivityMode)
        rearviewViewController.delegate = self
        rearviewViewController.view.addGestureRecognizer(doubleTapGestureRecognizer)
        rearviewViewController.tapGestureRecognizer.require(toFail: doubleTapGestureRecognizer)

        window.rootViewController = rearviewViewController
        window.makeKeyAndVisible()

        if isHandedOffFromOtherApp {
            isHandedOffFromOtherApp = false

            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { (timer) in
                rearviewViewController.start()
            }
        } else {
            rearviewViewController.start()
        }

        self.rearviewViewController = rearviewViewController
    }

    func showAlertAboutInvalidRaspberryPiAddress(window: UIWindow) {
        let alertController = UIAlertController(
            title: nil,
            message: "You need to specity your Raspberry Pi address in the Settings app.",
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: "OK", style: .default))

        window.rootViewController = UIViewController()
        window.makeKeyAndVisible()
        window.rootViewController?.present(alertController, animated: true)
    }

    func stopIfNeeded() {
        rearviewViewController?.stop()
        rearviewViewController = nil
    }

    @objc func gestureRecognizerDidRecognizeDoubleTap() {
        handOffToDashApp()
    }

    func handOffToDashApp() {
        stopIfNeeded()

        var urlComponents = URLComponents()
        urlComponents.scheme = "dash"
        urlComponents.host = "rearview"
        urlComponents.path = "/handoff"

        UIApplication.shared.open(urlComponents.url!, options: [:])
    }

    // https://developer.apple.com/library/archive/qa/qa1838/_index.html
    func showBlankScreen(window: UIWindow) {
        let blankViewController = UIViewController()
        blankViewController.view.backgroundColor = .black
        window.rootViewController = blankViewController
    }
}

extension RearviewManager: RearviewViewControllerDelegate {
    func rearviewViewController(didChangeCameraSensitivityMode cameraSensitivityMode: CameraSensitivityMode) {
        RearviewDefaults.shared.cameraSensitivityMode = cameraSensitivityMode
    }
}
