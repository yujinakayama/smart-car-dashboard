//
//  AppDelegate.swift
//  DashRemote
//
//  Created by Yuji Nakayama on 2020/01/28.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var vehicleProximityDetector: VehicleProximityDetector?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        updateVehicleProximityDetector()

        NotificationCenter.default.addObserver(forName: .PairedVehicleDidChangeDefaultVehicleID, object: nil, queue: nil) { [weak self] (notification) in
            self?.updateVehicleProximityDetector()
        }

        return true
    }

    func updateVehicleProximityDetector() {
        if let vehicleID = PairedVehicle.defaultVehicleID {
            vehicleProximityDetector = VehicleProximityDetector(vehicleID: vehicleID)
        } else {
            vehicleProximityDetector = nil
        }
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
}

