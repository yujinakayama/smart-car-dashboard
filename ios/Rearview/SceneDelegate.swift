//
//  SceneDelegate.swift
//  Rearview
//
//  Created by Yuji Nakayama on 2020/09/09.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit
import RearviewKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    var rearviewViewController: RearviewViewController?

    var isHandedOffFromOtherApp = false

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        guard let windowScene = (scene as? UIWindowScene) else { return }

        window = UIWindow(windowScene: windowScene)

        if let url = connectionOptions.urlContexts.first?.url {
            handle(url)
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not neccessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
        startIfPossible()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
        stopIfNeeded()
        showBlankScreen()
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        handle(url)
    }

    func handle(_ url: URL) {
        print(#function, url)

        switch url.host {
        case "handoff":
            isHandedOffFromOtherApp = true
        default:
            break
        }
    }

    func startIfPossible() {
        guard let window = window else { return }

        if let configuration = RearviewDefaults.shared.configuration {
            start(window: window, configuration: configuration)
        } else {
            showAlertAboutInvalidRaspberryPiAddress(window: window)
        }
    }

    func start(window: UIWindow, configuration: RearviewConfiguration) {
        let rearviewViewController = RearviewViewController(configuration: configuration, cameraSensitivityMode: RearviewDefaults.shared.cameraSensitivityMode)
        rearviewViewController.delegate = self
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

    // https://developer.apple.com/library/archive/qa/qa1838/_index.html
    func showBlankScreen() {
        guard let window = window else { return }
        let blankViewController = UIViewController()
        blankViewController.view.backgroundColor = .black
        window.rootViewController = blankViewController
    }
}

extension SceneDelegate: RearviewViewControllerDelegate {
    func rearviewViewController(didChangeCameraSensitivityMode cameraSensitivityMode: CameraSensitivityMode) {
        RearviewDefaults.shared.cameraSensitivityMode = cameraSensitivityMode
    }
}
