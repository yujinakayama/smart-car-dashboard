//
//  AppState.swift
//  Dash
//
//  Created by Yuji Nakayama on 2021/05/29.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import UIKit
import MapKit

@MainActor
class AppState {
    static let activityType = "com.yujinakayama.Dash.AppState"

    let window: UIWindow

    init(window: UIWindow) {
        self.window = window
    }

    var userActivityForPreservation: NSUserActivity {
        let preservation = Preservation(app: app)
        return preservation.userActivity
    }

    func restore(from userActivity: NSUserActivity) {
        guard let restoration = Restoration(userActivity: userActivity, app: app) else { return }
        restoration.perform()
    }

    private var app: App {
        return App(window: window)
    }
}

extension AppState {
    @MainActor
    class App {
        let window: UIWindow

        init(window: UIWindow) {
            self.window = window
        }

        lazy var storyboard = UIStoryboard(name: "Main", bundle: nil)

        var tabBarController: TabBarController {
            return window.rootViewController as! TabBarController
        }

        var dashboardViewController: DashboardViewController? {
            return tabBarController.viewController(for: .dashboard) as? DashboardViewController
        }

        var etcSplitViewController: ETCSplitViewController? {
            return tabBarController.viewController(for: .etc) as? ETCSplitViewController
        }

        var mapsViewController: MapsViewController? {
            let navigationController = tabBarController.viewController(for: .maps) as? UINavigationController
            return navigationController?.viewControllers.first as? MapsViewController
        }
    }
}

extension AppState {
    @MainActor
    class Preservation {
        let app: App

        init(app: App) {
            self.app = app
        }

        var userActivity: NSUserActivity {
            let userActivity = NSUserActivity(activityType: AppState.activityType)
            userActivity.userInfo = userInfo
            return userActivity
        }

        private var userInfo: [AnyHashable: Any] {
            let userInfo = AppState.propertyTypes.reduce(into: [String: Any]()) { (partialResult, type) in
                let property = type.init(app: app)

                if let value = property.serialize() {
                    partialResult[property.key] = value
                }
            }

            logger.debug(userInfo)

            return userInfo
        }
    }
}

extension AppState {
    @MainActor
    class Restoration {
        let userActivity: NSUserActivity
        let app: App

        init?(userActivity: NSUserActivity, app: App) {
            guard userActivity.activityType == AppState.activityType else { return nil }
            self.userActivity = userActivity
            self.app = app
        }

        func perform() {
            guard let userInfo = userActivity.userInfo else { return }

            UIView.performWithoutAnimation {
                for type in AppState.propertyTypes {
                    let property = type.init(app: app)

                    if let value = userInfo[property.key] {
                        property.restore(value)
                    }
                }
            }
        }
    }
}

extension AppState {
    @MainActor
    class Property {
        let app: App

        required init(app: AppState.App) {
            self.app = app
        }

        var key: String {
            return String(describing: Self.self)
        }

        func serialize() -> Any? {
            return nil
        }

        func restore(_ value: Any) {
        }
    }

    class SelectedTab: Property {
        override func serialize() -> Any? {
            return app.tabBarController.selectedIndex
        }

        override func restore(_ value: Any) {
            guard let value = value as? Int else { return }
            app.tabBarController.selectedIndex = value
        }
    }

    class DashboardLayoutMode: Property {
        override func serialize() -> Any? {
            return app.dashboardViewController?.currentLayoutMode.rawValue
        }

        override func restore(_ value: Any) {
            guard let value = value as? Int, let mode = DashboardViewController.LayoutMode(rawValue: value) else { return }
            app.dashboardViewController?.switchLayout(to: mode)
        }
    }

    class SelectedWidgetPage: Property {
        override func serialize() -> Any? {
            return app.dashboardViewController?.widgetViewController.currentPage
        }

        override func restore(_ value: Any) {
            guard let value = value as? Int else { return }
            app.dashboardViewController?.widgetViewController.currentPage = value
        }
    }

    class DisplayedETCPaymentHistory: Property {
        override func serialize() -> Any? {
            guard let paymentTableViewController = app.etcSplitViewController?.masterNavigationController.topViewController as? ETCPaymentTableViewController else {
                return nil
            }

            if let card = paymentTableViewController.card {
                return card.uuid.uuidString
            } else {
                return NSNull()
            }
        }

        override func restore(_ value: Any) {
            let paymentTableViewController = app.storyboard.instantiateViewController(identifier: "ETCPaymentTableViewController") as! ETCPaymentTableViewController

            if let value = value as? String, let cardUUID = UUID(uuidString: value) {
                paymentTableViewController.restoreCard(for: cardUUID)
            } else if value is NSNull {
                paymentTableViewController.card = nil
            } else {
                return
            }

            app.etcSplitViewController?.masterNavigationController.pushViewController(paymentTableViewController, animated: false)
        }
    }

    class MapsMapType: Property {
        override func serialize() -> Any? {
            return app.mapsViewController?.mapView.mapType.rawValue
        }

        override func restore(_ value: Any) {
            guard let value = value as? UInt, let mapType = MKMapType(rawValue: value) else { return }
            guard let mapsViewController = app.mapsViewController else { return }

            mapsViewController.mapTypeSegmentedControl.selectedMapType = mapType
            mapsViewController.mapTypeSegmentedControlDidChange()
        }
    }

    // We should order these in inner to outer order
    // to avoid "Unbalanced calls to begin/end appearance transitions" (view[Will/Did][Appear/Disappear]).
    static let propertyTypes: [Property.Type] = [
        SelectedWidgetPage.self,
        DashboardLayoutMode.self,
        DisplayedETCPaymentHistory.self,
        MapsMapType.self,
        SelectedTab.self,
    ]
}
