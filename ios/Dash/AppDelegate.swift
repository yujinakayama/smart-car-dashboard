//
//  AppDelegate.swift
//  ETC
//
//  Created by Yuji Nakayama on 2019/05/28.
//  Copyright © 2019 Yuji Nakayama. All rights reserved.
//

import UIKit
import ParkingSearchKit
import MapKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UISplitViewControllerDelegate {
    var window: UIWindow?

    let speedSensitiveVolumeController = SpeedSensitiveVolumeController(additonalValuePerOneMeterPerSecond: Defaults.shared.additonalVolumePerOneMeterPerSecond)

    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        _ = Firebase.shared
        return true
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        NotificationCenter.default.addObserver(self, selector: #selector(vehicleDidConnect), name: .VehicleDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(vehicleDidDisconnect), name: .VehicleDidDisconnect, object: nil)

        UserNotificationCenter.shared.setUp()

        Vehicle.default.connect()

        return true
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        startSpeedSensitiveVolumeControllerIfNeeded()
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        speedSensitiveVolumeController.stop()
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Firebase.shared.messaging.deviceToken = deviceToken
    }

    @objc func vehicleDidConnect() {
        startSpeedSensitiveVolumeControllerIfNeeded()
    }

    @objc func vehicleDidDisconnect() {
        speedSensitiveVolumeController.stop()
    }

    func startSpeedSensitiveVolumeControllerIfNeeded() {
        if Defaults.shared.isSpeedSensitiveVolumeControlEnabled, Vehicle.default.isConnected {
            speedSensitiveVolumeController.additonalValuePerOneMeterPerSecond = Defaults.shared.additonalVolumePerOneMeterPerSecond
            speedSensitiveVolumeController.start()
        }
    }
}
