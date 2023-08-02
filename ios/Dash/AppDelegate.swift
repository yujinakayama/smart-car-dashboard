//
//  AppDelegate.swift
//  ETC
//
//  Created by Yuji Nakayama on 2019/05/28.
//  Copyright © 2019 Yuji Nakayama. All rights reserved.
//

import UIKit
import MapboxCoreNavigation
import CacheKit
import ParkingSearchKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UISplitViewControllerDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        _ = Firebase.shared
        return true
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UserNotificationCenter.shared.setUp()
        Vehicle.default.connect()

        if Defaults.shared.clearCachesOnNextLaunch {
            caches.forEach { $0.clear() }
            Defaults.shared.clearCachesOnNextLaunch = false
        }

        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        logger.info()
        Firebase.shared.messaging.deviceToken = deviceToken
    }
    
    var caches: [Cache] {
        [
            ArtworkView.appleMusicImageCache,
            SongDataRequest.cache,
            WebsiteIcon.cache,
            LocationTracker.cache,
            AppleMaps.PointOfInterestFinder.cache,
            ImageLoader.cache,
            OfficialParkingSearch.cache
        ]
    }
}
