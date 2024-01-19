//
//  RearviewWidgetViewController.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/11/21.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit
import RearviewKit
import FloatingViewKit

class RearviewWidgetViewController: UIViewController {
    var rearviewViewController: RearviewViewController?

    var floatingWidgetContainerController: FloatingViewContainerController!

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

    // Invoke child appearance methods manually because for some reason viewDidDissapear is not called automatically
    override var shouldAutomaticallyForwardAppearanceMethods: Bool {
        false
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        overrideUserInterfaceStyle = .dark
        view.backgroundColor = .black

        let notificationCenter = NotificationCenter.default

        notificationCenter.addObserver(self, selector: #selector(sceneWillEnterForeground), name: UIScene.willEnterForegroundNotification, object: nil)

        notificationCenter.addObserver(self, selector: #selector(sceneDidEnterBackground), name: UIScene.didEnterBackgroundNotification, object: nil)

        notificationCenter.addObserver(self, selector: #selector(vehicleDidConnect), name: .VehicleDidConnect, object: nil)

        notificationCenter.addObserver(self, selector: #selector(vehicleDidDisconnect), name: .VehicleDidDisconnect, object: nil)

        setUpFloatingWidgetContainerController()
        setUpRearviewViewControllerIfPossible()
    }

    func setUpFloatingWidgetContainerController() {
        floatingWidgetContainerController = FloatingViewContainerController(
            floatingViewController: instanciateWidgetViewController(),
            initialPosition: Defaults.shared.floatingWidgetPositionInRearviewWidget
        )
        floatingWidgetContainerController.delegate = self
        floatingWidgetContainerController.additionalSafeAreaInsets = .init(top: 0, left: 24, bottom: 0, right: 24)
        floatingWidgetContainerController.view.translatesAutoresizingMaskIntoConstraints = false

        addChild(floatingWidgetContainerController)
        view.addSubview(floatingWidgetContainerController.view)
        NSLayoutConstraint.activate([
            floatingWidgetContainerController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: floatingWidgetContainerController.view.trailingAnchor),
            floatingWidgetContainerController.view.topAnchor.constraint(equalTo: view.topAnchor),
            view.bottomAnchor.constraint(equalTo: floatingWidgetContainerController.view.bottomAnchor),
        ])
        floatingWidgetContainerController.didMove(toParent: self)
    }

    func instanciateWidgetViewController() -> LocationInformationWidgetViewController {
        let storyboard = UIStoryboard(name: "Widgets", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "LocationInformationWidgetViewController") as! LocationInformationWidgetViewController
        viewController.view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            viewController.view.widthAnchor.constraint(equalToConstant: 280),
            viewController.view.heightAnchor.constraint(equalToConstant: 78)
        ])
        
        viewController.scaleLabelFontSizes(scale: 0.9)
        viewController.showsLocationAccuracyWarning = false
        viewController.activityIndicatorView.style = .medium

        return viewController
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
        view.insertSubview(rearviewViewController.view, belowSubview: floatingWidgetContainerController.view)
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

        view.insertSubview(label, belowSubview: floatingWidgetContainerController.view)

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

    func showOrHideFloatingWidgetViewIfNeeded() {
        if traitCollection.horizontalSizeClass == .compact {
            floatingWidgetContainerController.hideFloatingView()
        } else {
            floatingWidgetContainerController.showFloatingView()
        }
    }

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

        showOrHideFloatingWidgetViewIfNeeded()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        isVisible = true
        startIfNeeded()
        showOrHideFloatingWidgetViewIfNeeded()
        children.forEach { $0.beginAppearanceTransition(true, animated: animated) }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        children.forEach { $0.endAppearanceTransition() }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        children.forEach { $0.beginAppearanceTransition(false, animated: animated) }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        isVisible = false
        stop()
        children.forEach { $0.endAppearanceTransition() }
    }

    @objc func sceneWillEnterForeground() {
        setUpRearviewViewControllerIfPossible()
        startIfNeeded()
        showOrHideFloatingWidgetViewIfNeeded()
    }

    @objc func sceneDidEnterBackground() {
        tearDownRearviewViewControllerIfNeeded()
        floatingWidgetContainerController.hideFloatingView()
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

extension RearviewWidgetViewController: FloatingViewContainerControllerDelegate {
    func floatingViewContainerController(_ containerController: FloatingViewContainerController, didChangePosition position: FloatingPosition) {
        Defaults.shared.floatingWidgetPositionInRearviewWidget = position
    }
}
