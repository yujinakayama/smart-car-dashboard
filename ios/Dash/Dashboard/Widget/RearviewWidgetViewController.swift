//
//  RearviewWidgetViewController.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/11/21.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit
import RearviewKit

class RearviewWidgetViewController: UIViewController {
    var rearviewViewController: RearviewViewController?

    lazy var widgetViewController: LocationInformationWidgetViewController = {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "LocationInformationWidgetViewController") as! LocationInformationWidgetViewController

        viewController.view.backgroundColor = viewController.view.backgroundColor?.withAlphaComponent(0.93)
        viewController.view.layer.cornerCurve = .continuous
        viewController.view.layer.cornerRadius = 8
        viewController.view.translatesAutoresizingMaskIntoConstraints = false

        viewController.scaleLabelFontSizes(scale: 0.9)
        viewController.showsLocationAccuracyWarning = false
        viewController.activityIndicatorView.style = .medium

        return viewController
    }()

    var isVisible = false

    var justHandedOffFromOtherApp: Bool {
        get {
            if let lastHandOffTimeFromOtherApp = lastHandOffTimeFromOtherApp {
                return Date().timeIntervalSince(lastHandOffTimeFromOtherApp) < 1
            } else {
                return false
            }
        }

        set {
            if newValue {
                lastHandOffTimeFromOtherApp = Date()
            } else {
                lastHandOffTimeFromOtherApp = nil
            }
        }
    }

    private var lastHandOffTimeFromOtherApp: Date?

    lazy var doubleTapGestureRecognizer: UITapGestureRecognizer = {
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(gestureRecognizerDidRecognizeDoubleTap))
        gestureRecognizer.numberOfTapsRequired = 2
        return gestureRecognizer
    }()

    var warningLabel: UILabel?

    override func viewDidLoad() {
        super.viewDidLoad()

        overrideUserInterfaceStyle = .dark
        view.backgroundColor = .black

        let notificationCenter = NotificationCenter.default

        notificationCenter.addObserver(self, selector: #selector(sceneWillEnterForeground), name: UIScene.willEnterForegroundNotification, object: nil)

        notificationCenter.addObserver(self, selector: #selector(sceneDidEnterBackground), name: UIScene.didEnterBackgroundNotification, object: nil)

        notificationCenter.addObserver(self, selector: #selector(vehicleDidConnect), name: .VehicleDidConnect, object: nil)

        notificationCenter.addObserver(self, selector: #selector(vehicleDidDisconnect), name: .VehicleDidDisconnect, object: nil)

        setUpRearviewViewControllerIfPossible()
    }

    func setUpRearviewViewControllerIfPossible() {
        if let configuration = RearviewDefaults.shared.configuration {
            setUpRearviewViewController(configuration: configuration)
        } else {
            warnAboutInvalidRaspberryPiAddress()
        }
    }

    func setUpRearviewViewController(configuration: RearviewConfiguration) {
        guard rearviewViewController == nil else { return }

        let rearviewViewController = RearviewViewController(configuration: configuration, cameraSensitivityMode: RearviewDefaults.shared.cameraSensitivityMode)
        rearviewViewController.delegate = self
        rearviewViewController.contentMode = .top

        addChild(rearviewViewController)
        rearviewViewController.view.frame = view.bounds
        view.addSubview(rearviewViewController.view)
        rearviewViewController.didMove(toParent: self)

        rearviewViewController.view.addGestureRecognizer(doubleTapGestureRecognizer)
        rearviewViewController.tapGestureRecognizer.require(toFail: doubleTapGestureRecognizer)

        self.rearviewViewController = rearviewViewController
    }

    func warnAboutInvalidRaspberryPiAddress() {
        let label = UILabel()
        label.text = "You need to specity your Raspberry Pi address in the Settings app."
        label.textColor = UIColor(white: 1, alpha: 0.5)
        label.numberOfLines = 0
        label.textAlignment = .center

        view.addSubview(label)

        label.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8)
        ])

        warningLabel = label
    }

    func tearDownRearviewViewControllerIfNeeded() {
        guard let rearviewViewController = rearviewViewController else { return }

        stop()

        rearviewViewController.willMove(toParent: nil)
        rearviewViewController.view.removeFromSuperview()
        rearviewViewController.removeFromParent()

        self.rearviewViewController = nil
    }

    func startIfNeeded() {
        guard isVisible, Vehicle.default.isConnected else { return }

        if justHandedOffFromOtherApp {
            justHandedOffFromOtherApp = false

            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] (timer) in
                self?.rearviewViewController?.start()
            }
        } else {
            rearviewViewController?.start()
        }
    }

    func stop() {
        rearviewViewController?.stop()
    }

    func setUpOrTearDownWidgetViewControllerIfNeeded() {
        if traitCollection.horizontalSizeClass == .compact {
            tearDownWidgetViewControllerIfNeeded()
        } else {
            setUpWidgetViewControllerIfNeeded()
        }
    }

    func setUpWidgetViewControllerIfNeeded() {
        guard widgetViewController.parent != self else { return }

        addChild(widgetViewController)
        view.addSubview(widgetViewController.view)
        NSLayoutConstraint.activate(widgetViewControllerConstraints)
        widgetViewController.didMove(toParent: self)
    }

    func tearDownWidgetViewControllerIfNeeded() {
        guard widgetViewController.parent == self else { return }

        widgetViewController.willMove(toParent: nil)
        NSLayoutConstraint.deactivate(widgetViewControllerConstraints)
        widgetViewController.view.removeFromSuperview()
        widgetViewController.removeFromParent()
    }

    lazy var widgetViewControllerConstraints = [
        widgetViewController.view.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 20),
        view.safeAreaLayoutGuide.bottomAnchor.constraint(equalTo: widgetViewController.view.bottomAnchor),
        widgetViewController.view.widthAnchor.constraint(equalToConstant: 280),
        widgetViewController.view.heightAnchor.constraint(equalToConstant: 78)
    ]

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        // traitCollectionDidChange() is invoked when the scene just entered background
        // and it reports wrong horizontalSizeClass, so we ignore it
        guard let scene = view.window?.windowScene,
              (scene.activationState == .foregroundActive || scene.activationState == .foregroundInactive)
        else { return }

        if let rearviewViewController = rearviewViewController {
            if traitCollection.horizontalSizeClass == .compact {
                rearviewViewController.sensitivityModeControlPosition = .center
            } else {
                rearviewViewController.sensitivityModeControlPosition = .bottom
            }
        }

        setUpOrTearDownWidgetViewControllerIfNeeded()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        isVisible = true
        startIfNeeded()
        setUpOrTearDownWidgetViewControllerIfNeeded()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        isVisible = false
        stop()
        tearDownWidgetViewControllerIfNeeded()
    }

    @objc func sceneWillEnterForeground() {
        setUpRearviewViewControllerIfPossible()
        startIfNeeded()
        setUpOrTearDownWidgetViewControllerIfNeeded()
    }

    @objc func sceneDidEnterBackground() {
        tearDownRearviewViewControllerIfNeeded()
        tearDownWidgetViewControllerIfNeeded()

        warningLabel?.removeFromSuperview()
        warningLabel = nil
    }

    @objc func vehicleDidConnect() {
        startIfNeeded()
    }

    @objc func vehicleDidDisconnect() {
        stop()
    }

    @objc func gestureRecognizerDidRecognizeDoubleTap() {
        handOffToRearviewApp()
    }

    func handOffToRearviewApp() {
        stop()

        var urlComponents = URLComponents()
        urlComponents.scheme = "rearview"
        urlComponents.host = "handoff"

        UIApplication.shared.open(urlComponents.url!, options: [:])
    }
}

extension RearviewWidgetViewController: RearviewViewControllerDelegate {
    func rearviewViewController(didChangeCameraSensitivityMode cameraSensitivityMode: CameraSensitivityMode) {
        RearviewDefaults.shared.cameraSensitivityMode = cameraSensitivityMode
    }
}
