//
//  AppState.swift
//  Dash
//
//  Created by Yuji Nakayama on 2021/05/29.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import UIKit

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
    class App {
        let window: UIWindow

        init(window: UIWindow) {
            self.window = window
        }

        var tabBarController: TabBarController {
            return window.rootViewController as! TabBarController
        }

        var dashboardViewController: DashboardViewController? {
            return tabBarController.viewController(for: .dashboard) as? DashboardViewController
        }
    }
}

extension AppState {
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

            for type in AppState.propertyTypes {
                let property = type.init(app: app)

                if let value = userInfo[property.key] {
                    property.restore(value)
                }
            }
        }
    }
}

extension AppState {
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

    static let propertyTypes: [Property.Type] = [
        SelectedTab.self,
        DashboardLayoutMode.self,
        SelectedWidgetPage.self
    ]
}
