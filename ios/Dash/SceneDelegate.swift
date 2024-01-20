//
//  SceneDelegate.swift
//  Dash
//
//  Created by Yuji Nakayama on 2021/10/24.
//

import UIKit
import MapKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    var pendingURL: URL?

    var tabBarController: TabBarController {
        return window?.rootViewController as! TabBarController
    }

    lazy var tabBarBadgeManager = TabBarBadgeManager(tabBarController: tabBarController)

    let assistant = Assistant()

    let speedSensitiveVolumeController = SpeedSensitiveVolumeController(
        additonalValuePerOneMeterPerSecond: Defaults.shared.additonalVolumePerOneMeterPerSecond,
        minimumSpeedForAdditionalVolume: Defaults.shared.minimumSpeedForAdditionalVolume
    )

    var statusBarManager: StatusBarManager?
    var climateStatusManager: ClimateStatusManager?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        guard let windowScene = (scene as? UIWindowScene) else { return }

        _ = tabBarBadgeManager

        if Defaults.shared.showClimateInStatusBar, let homeName = Defaults.shared.homeKitHomeName {
            let statusBarManager = StatusBarManager(windowScene: windowScene)
            climateStatusManager = .init(homeName: homeName, statusBarManager: statusBarManager)
            self.statusBarManager = statusBarManager
        }

        NotificationCenter.default.addObserver(self, selector: #selector(vehicleDidConnect), name: .VehicleDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(vehicleDidDisconnect), name: .VehicleDidDisconnect, object: nil)

        // https://hakobune.co.jp/category/engineer-blog/2584/
        // https://developer.apple.com/documentation/xcode/defining-a-custom-url-scheme-for-your-app
        if let url = connectionOptions.urlContexts.first?.url {
            // Process the URL in sceneDidBecomeActive(_:)
            // because at this time not all views are available.
            pendingURL = url
        }
    }

    // https://developer.apple.com/videos/play/wwdc2021/10057/
    func scene(_ scene: UIScene, restoreInteractionStateWith stateRestorationActivity: NSUserActivity) {
        appState?.restore(from: stateRestorationActivity)
    }

    func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
        return appState?.userActivityForPreservation
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.

        if let pendingURL = pendingURL {
            handleURL(pendingURL)
        }

        pendingURL = nil

        startSpeedSensitiveVolumeControllerIfNeeded()
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).

        // We stop the volume controller here rather than sceneDidEnterBackground()
        // since it may unintentionally display the system volume indicator.
        speedSensitiveVolumeController.stop(resetToBaseValue: false)
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
        startOrStopLocationTracker()
        statusBarManager?.update()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        handleURL(url)
    }

    func windowScene(_ windowScene: UIWindowScene, didUpdate previousCoordinateSpace: UICoordinateSpace, interfaceOrientation previousInterfaceOrientation: UIInterfaceOrientation, traitCollection previousTraitCollection: UITraitCollection) {
        statusBarManager?.update()
    }

    private func handleURL(_ url: URL) {
        if Firebase.shared.authentication.handle(url) {
            return
        }

        if url.host == "rearview", url.path == "/handoff" {
            handleRearviewHandOffFromOtherApp()
        } else if let urlItem = ParkingSearchURLItem(url: url) {
            searchParkingsInMaps(mapItem: urlItem.mapItem)
        }
    }

    private func handleRearviewHandOffFromOtherApp() {
        guard let dashboardViewController = tabBarController.viewController(for: .dashboard) as? DashboardViewController,
              let rearviewWidgetViewController = dashboardViewController.widgetViewController.viewControllers?.first(where: { $0 is RearviewWidgetViewController }) as? RearviewWidgetViewController
        else { return }

        rearviewWidgetViewController.justHandedOffFromOtherApp = true
    }

    private func searchParkingsInMaps(mapItem: MKMapItem) {
        let navigationController = tabBarController.viewController(for: .maps) as! UINavigationController
        let mapsViewController = navigationController.topViewController as! MapsViewController
        mapsViewController.startSearchingParkings(destination: mapItem)
        tabBarController.selectedViewController = navigationController
    }

    private var appState: AppState? {
        guard let window = window else { return nil }
        return AppState(window: window)
    }

    @objc func vehicleDidConnect() {
        startOrStopLocationTracker()
        startSpeedSensitiveVolumeControllerIfNeeded()
    }

    @objc func vehicleDidDisconnect() {
        startOrStopLocationTracker()
        speedSensitiveVolumeController.stop(resetToBaseValue: true)
    }

    func startOrStopLocationTracker() {
        if Defaults.shared.showTrackOnMaps, Vehicle.default.isConnected {
            LocationTracker.shared.startTracking()
        } else {
            LocationTracker.shared.stopTracking()
        }
    }

    func startSpeedSensitiveVolumeControllerIfNeeded() {
        guard Defaults.shared.isSpeedSensitiveVolumeControlEnabled,
              Vehicle.default.isConnected
        else { return }

        speedSensitiveVolumeController.additonalValuePerOneMeterPerSecond = Defaults.shared.additonalVolumePerOneMeterPerSecond
        speedSensitiveVolumeController.minimumSpeedForAdditionalVolume = Defaults.shared.minimumSpeedForAdditionalVolume
        speedSensitiveVolumeController.start()
    }
}

